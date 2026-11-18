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
        { status: 'error', message: 'Nomor invoice wajib diisi.' },
        { status: 400 }
      );
    }

    const { data: transaction, error: findErr } = await supabaseAdmin
      .from('transactions')
      .select('*, items:transaction_items(*)')
      .eq('invoice_no', invoice_no)
      .eq('customer_id', customer.id)
      .maybeSingle();

    if (findErr || !transaction) {
      return NextResponse.json(
        { status: 'error', message: 'Transaksi tidak ditemukan.' },
        { status: 404 }
      );
    }

    // If already paid/completed, return immediately
    if (['paid', 'diambil', 'selesai'].includes(transaction.status)) {
      return NextResponse.json({
        status: 'success',
        data: transaction,
      });
    }

    // Query Midtrans Status API using server key
    const settings = await getIntegrationSettings();
    const serverKey = settings.midtransServerKey;
    if (!serverKey || serverKey.includes('demo')) {
      return NextResponse.json({
        status: 'success',
        data: transaction,
      });
    }

    const statusBaseUrl = settings.midtransIsProduction
      ? 'https://api.midtrans.com'
      : 'https://api.sandbox.midtrans.com';
    const authHeader = 'Basic ' + Buffer.from(`${serverKey}:`).toString('base64');

    const midtransRes = await fetch(
      `${statusBaseUrl}/v2/${encodeURIComponent(invoice_no)}/status`,
      {
        method: 'GET',
        headers: {
          Accept: 'application/json',
          Authorization: authHeader,
        },
        cache: 'no-store',
      }
    );

    if (!midtransRes.ok) {
      return NextResponse.json({
        status: 'success',
        data: transaction,
      });
    }

    const midtransData = await midtransRes.json();
    const transactionStatus = midtransData.transaction_status;
    const fraudStatus = midtransData.fraud_status;
    const paymentType = midtransData.payment_type;

    let mappedMethod = transaction.payment_method || 'qris';
    if (paymentType) {
      if (['qris', 'gopay', 'shopeepay'].includes(paymentType)) {
        mappedMethod = 'qris';
      } else if (['credit_card', 'card'].includes(paymentType)) {
        mappedMethod = 'kartu';
      } else if (['bank_transfer', 'echannel', 'permata_va', 'cstore'].includes(paymentType)) {
        mappedMethod = 'va';
      }
    }

    const isPaid =
      transactionStatus === 'settlement' ||
      (transactionStatus === 'capture' && (!fraudStatus || fraudStatus === 'accept'));

    if (isPaid) {
      const qrToken =
        transaction.qr_token ||
        'PKP-' + crypto.randomBytes(12).toString('hex').toUpperCase();

      const { data: updated } = await supabaseAdmin
        .from('transactions')
        .update({
          status: 'paid',
          payment_method: mappedMethod,
          paid_at: new Date().toISOString(),
          qr_token: qrToken,
          updated_at: new Date().toISOString(),
        })
        .eq('id', transaction.id)
        .eq('status', 'pending') // guard against double stock deduction
        .select('*, items:transaction_items(*)')
        .maybeSingle();

      if (updated) {
        // Deduct product stock only when status transitioned from pending -> paid
        if (transaction.items && Array.isArray(transaction.items)) {
          for (const item of transaction.items) {
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
          message: 'Pembayaran berhasil dikonfirmasi!',
          data: updated,
        });
      }

      // If another request (e.g. webhook) already marked it paid concurrently, fetch latest
      const { data: latest } = await supabaseAdmin
        .from('transactions')
        .select('*, items:transaction_items(*)')
        .eq('id', transaction.id)
        .maybeSingle();

      return NextResponse.json({
        status: 'success',
        data: latest || transaction,
      });
    } else if (['deny', 'cancel', 'expire'].includes(transactionStatus)) {
      const newStatus = transactionStatus === 'expire' ? 'expired' : 'gagal';
      const { data: updated } = await supabaseAdmin
        .from('transactions')
        .update({ status: newStatus, updated_at: new Date().toISOString() })
        .eq('id', transaction.id)
        .select('*, items:transaction_items(*)')
        .maybeSingle();

      return NextResponse.json({
        status: 'success',
        data: updated || { ...transaction, status: newStatus },
      });
    }

    return NextResponse.json({
      status: 'success',
      data: transaction,
    });
  } catch (err: any) {
    console.error('[verify-payment error]', err);
    return NextResponse.json(
      { status: 'error', message: err.message || 'Gagal memverifikasi status pembayaran.' },
      { status: 500 }
    );
  }
}
