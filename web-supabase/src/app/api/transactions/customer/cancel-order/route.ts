import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json({ status: 'error', message: 'Silakan login terlebih dahulu.' }, { status: 401 });
    }

    const body = await req.json();
    const { transaction_id, invoice_no } = body;

    let query = supabaseAdmin
      .from('transactions')
      .select('id, invoice_no, status, payment_method')
      .eq('customer_id', customer.id);

    if (transaction_id) {
      query = query.eq('id', transaction_id);
    } else if (invoice_no) {
      query = query.eq('invoice_no', invoice_no);
    } else {
      return NextResponse.json(
        { status: 'error', message: 'ID transaksi atau nomor invoice dibutuhkan.' },
        { status: 400 }
      );
    }

    const { data: trx, error: findErr } = await query.maybeSingle();

    if (findErr || !trx) {
      return NextResponse.json({ status: 'error', message: 'Pesanan tidak ditemukan.' }, { status: 404 });
    }

    // Only allow cancelling pending orders
    if (trx.status !== 'pending') {
      return NextResponse.json(
        { status: 'error', message: 'Hanya pesanan yang belum dibayar / masih pending yang dapat dibatalkan.' },
        { status: 400 }
      );
    }

    // 1. Delete transaction_items
    await supabaseAdmin.from('transaction_items').delete().eq('transaction_id', trx.id);

    // 2. Delete transaction permanently
    const { error: delErr } = await supabaseAdmin.from('transactions').delete().eq('id', trx.id);
    if (delErr) {
      return NextResponse.json({ status: 'error', message: delErr.message }, { status: 500 });
    }

    return NextResponse.json({
      status: 'success',
      message: `Pesanan ${trx.invoice_no} berhasil dibatalkan dan dihapus.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
