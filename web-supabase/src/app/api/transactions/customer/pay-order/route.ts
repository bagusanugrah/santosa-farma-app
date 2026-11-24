import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';
import { getIntegrationSettings } from '@/lib/settings';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json(
        { status: 'error', message: 'Silakan login terlebih dahulu.' },
        { status: 401 }
      );
    }

    const body = await req.json();
    const { invoice_no } = body;

    if (!invoice_no) {
      return NextResponse.json(
        { status: 'error', message: 'Nomor invoice dibutuhkan.' },
        { status: 400 }
      );
    }

    const { data: trx, error: findErr } = await supabaseAdmin
      .from('transactions')
      .select('*, items:transaction_items(*)')
      .eq('invoice_no', invoice_no)
      .eq('customer_id', customer.id)
      .maybeSingle();

    if (findErr || !trx) {
      return NextResponse.json(
        { status: 'error', message: 'Pesanan tidak ditemukan.' },
        { status: 404 }
      );
    }

    // If order is already paid, return early
    if (['paid', 'diambil', 'selesai'].includes(trx.status)) {
      return NextResponse.json({
        status: 'success',
        data: {
          is_paid: true,
          status: trx.status,
          invoice_no: trx.invoice_no,
        },
      });
    }

    const settings = await getIntegrationSettings();
    const serverKey = settings.midtransServerKey;
    const isProd = settings.midtransIsProduction;
    const clientKey = settings.midtransClientKey;

    const statusBaseUrl = isProd
      ? 'https://api.midtrans.com'
      : 'https://api.sandbox.midtrans.com';
    const snapBaseUrl = isProd
      ? 'https://app.midtrans.com'
      : 'https://app.sandbox.midtrans.com';
    const authHeader = 'Basic ' + Buffer.from(`${serverKey}:`).toString('base64');

    let paymentDetails: any = null;

    // 1. Check current status on Midtrans
    if (serverKey) {
      try {
        const midtransRes = await fetch(
          `${statusBaseUrl}/v2/${encodeURIComponent(invoice_no)}/status`,
          {
            headers: {
              Accept: 'application/json',
              Authorization: authHeader,
            },
            cache: 'no-store',
          }
        );

        if (midtransRes.ok) {
          const midtransData = await midtransRes.json();
          const tStatus = midtransData.transaction_status;
          const fStatus = midtransData.fraud_status;

          // If paid on Midtrans side, auto mark paid in our DB
          if (
            tStatus === 'settlement' ||
            (tStatus === 'capture' && (!fStatus || fStatus === 'accept'))
          ) {
            const qrToken =
              trx.qr_token ||
              'PKP-' + crypto.randomBytes(12).toString('hex').toUpperCase();

            let mappedMethod = trx.payment_method || 'qris';
            if (midtransData.payment_type) {
              if (['qris', 'gopay', 'shopeepay'].includes(midtransData.payment_type)) {
                mappedMethod = 'qris';
              } else if (['credit_card', 'card'].includes(midtransData.payment_type)) {
                mappedMethod = 'kartu';
              } else if (
                ['bank_transfer', 'echannel', 'permata_va', 'cstore'].includes(
                  midtransData.payment_type
                )
              ) {
                mappedMethod = 'va';
              }
            }

            const { data: updated } = await supabaseAdmin
              .from('transactions')
              .update({
                status: 'paid',
                payment_method: mappedMethod,
                paid_at: new Date().toISOString(),
                qr_token: qrToken,
                updated_at: new Date().toISOString(),
              })
              .eq('id', trx.id)
              .eq('status', 'pending')
              .select('*, items:transaction_items(*)')
              .maybeSingle();

            if (updated && trx.items && Array.isArray(trx.items)) {
              for (const item of trx.items) {
                if (item.product_id) {
                  const { data: prod } = await supabaseAdmin
                    .from('products')
                    .select('stock')
                    .eq('id', item.product_id)
                    .maybeSingle();

                  if (prod) {
                    const newStock = Math.max(0, Number(prod.stock) - Number(item.qty));
                    await supabaseAdmin
                      .from('products')
                      .update({ stock: newStock })
                      .eq('id', item.product_id);
                  }
                }
              }
            }

            return NextResponse.json({
              status: 'success',
              data: {
                is_paid: true,
                status: 'paid',
                invoice_no: trx.invoice_no,
              },
            });
          }

          // Extract payment instructions if pending
          let bankName = null;
          let vaNumber = null;
          let billKey = null;
          let billerCode = null;
          let qrUrl = null;

          if (
            midtransData.va_numbers &&
            Array.isArray(midtransData.va_numbers) &&
            midtransData.va_numbers.length > 0
          ) {
            bankName = midtransData.va_numbers[0].bank?.toUpperCase();
            vaNumber = midtransData.va_numbers[0].va_number;
          } else if (midtransData.permata_va_number) {
            bankName = 'PERMATA';
            vaNumber = midtransData.permata_va_number;
          } else if (midtransData.bill_key && midtransData.biller_code) {
            bankName = 'MANDIRI';
            billKey = midtransData.bill_key;
            billerCode = midtransData.biller_code;
          }

          if (midtransData.actions && Array.isArray(midtransData.actions)) {
            const qrAct = midtransData.actions.find(
              (a: any) => a.name === 'generate-qr-code'
            );
            if (qrAct) {
              qrUrl = qrAct.url;
            }
          }

          paymentDetails = {
            payment_type: midtransData.payment_type,
            bank_name: bankName,
            va_number: vaNumber,
            bill_key: billKey,
            biller_code: billerCode,
            qr_url: qrUrl,
            expiry_time: midtransData.expiry_time,
          };
        }
      } catch (e) {
        console.error('Midtrans status check error:', e);
      }
    }

    // 2. Ensure we have a valid Snap Token
    let snapToken = trx.midtrans_snap_token;
    if (!snapToken && serverKey) {
      try {
        const snapRes = await fetch(`${snapBaseUrl}/snap/v1/transactions`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            Authorization: authHeader,
          },
          body: JSON.stringify({
            transaction_details: {
              order_id: trx.invoice_no,
              gross_amount: Math.round(Number(trx.total)),
            },
            customer_details: {
              first_name: customer.name || 'Pelanggan',
              email: customer.email || 'customer@santosa.com',
              phone: customer.phone || '081234567890',
            },
          }),
        });

        if (snapRes.ok) {
          const snapData = await snapRes.json();
          snapToken = snapData.token;
          await supabaseAdmin
            .from('transactions')
            .update({ midtrans_snap_token: snapToken })
            .eq('id', trx.id);
        }
      } catch (e) {
        console.error('Create snap token error:', e);
      }
    }

    return NextResponse.json({
      status: 'success',
      data: {
        is_paid: false,
        status: trx.status,
        invoice_no: trx.invoice_no,
        total: trx.total,
        snap_token: snapToken,
        client_key: clientKey,
        is_production: isProd,
        payment_details: paymentDetails,
      },
    });
  } catch (err: any) {
    console.error('[pay-order error]', err);
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
