import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';
import { getIntegrationSettings } from '@/lib/settings';
import { syncAndCleanPendingMidtransOrder } from '@/lib/midtrans-cleanup';

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

    const settings = await getIntegrationSettings();
    const syncResult = await syncAndCleanPendingMidtransOrder(transaction, settings);

    if (syncResult.state === 'paid') {
      return NextResponse.json({
        status: 'success',
        message: 'Pembayaran berhasil dikonfirmasi!',
        data: syncResult.transaction,
      });
    }

    if (syncResult.state === 'deleted') {
      return NextResponse.json({
        status: 'success',
        deleted: true,
        is_expired: true,
        message: 'Batas waktu pembayaran telah berakhir. Pesanan otomatis dibatalkan dan dihapus.',
        data: null,
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
