import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';
import { getIntegrationSettings } from '@/lib/settings';
import {
  getRequestOrigin,
  syncAndCleanPendingMidtransOrder,
} from '@/lib/midtrans-cleanup';

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

    const syncResult = await syncAndCleanPendingMidtransOrder(trx, settings);

    if (syncResult.state === 'paid') {
      return NextResponse.json({
        status: 'success',
        data: {
          is_paid: true,
          status: 'paid',
          invoice_no: trx.invoice_no,
        },
      });
    }

    if (syncResult.state === 'deleted') {
      return NextResponse.json({
        status: 'success',
        data: {
          is_paid: false,
          is_expired: true,
          deleted: true,
          status: 'expired',
          invoice_no: trx.invoice_no,
        },
      });
    }

    const paymentDetails = syncResult.paymentDetails;

    // Ensure we have a valid Snap Token
    const snapBaseUrl = isProd
      ? 'https://app.midtrans.com'
      : 'https://app.sandbox.midtrans.com';
    const authHeader = 'Basic ' + Buffer.from(`${serverKey}:`).toString('base64');

    let snapToken = trx.midtrans_snap_token;
    if (!snapToken && serverKey) {
      const origin = getRequestOrigin(req);
      const finishUrl = `${origin}/orders/${encodeURIComponent(trx.invoice_no)}`;
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
            callbacks: {
              finish: finishUrl,
              error: finishUrl,
              pending: finishUrl,
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
