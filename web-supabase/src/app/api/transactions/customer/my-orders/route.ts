import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';

export async function GET(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json({ status: 'error', message: 'Silakan login terlebih dahulu.' }, { status: 401 });
    }

    const { data: transactions, error } = await supabaseAdmin
      .from('transactions')
      .select('*, items:transaction_items(*)')
      .eq('customer_id', customer.id)
      .order('id', { ascending: false });

    if (error) {
      return NextResponse.json(
        { status: 'error', message: error.message || 'Gagal mengambil riwayat pesanan.' },
        { status: 500 }
      );
    }

    return NextResponse.json({
      status: 'success',
      data: transactions || [],
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
