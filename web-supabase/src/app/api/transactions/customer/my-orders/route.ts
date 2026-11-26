import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';
import { getIntegrationSettings } from '@/lib/settings';
import {
  isPharmacyPaymentMethod,
  syncAndCleanPendingMidtransOrder,
} from '@/lib/midtrans-cleanup';

export const dynamic = 'force-dynamic';

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
      .not('status', 'in', '("dibatalkan","expired","gagal")')
      .order('id', { ascending: false });

    if (error) {
      return NextResponse.json(
        { status: 'error', message: error.message || 'Gagal mengambil riwayat pesanan.' },
        { status: 500 }
      );
    }

    const list = transactions || [];
    const pendingMidtrans = list.filter(
      (t) => t.status === 'pending' && !isPharmacyPaymentMethod(t.payment_method)
    );

    let activeTransactions = list;
    if (pendingMidtrans.length > 0) {
      const settings = await getIntegrationSettings();
      const results = await Promise.all(
        pendingMidtrans.map(async (trx) => ({
          id: trx.id,
          result: await syncAndCleanPendingMidtransOrder(trx, settings),
        }))
      );

      const deletedIds = new Set<number>();
      const paidMap = new Map<number, any>();
      for (const r of results) {
        if (r.result.state === 'deleted') deletedIds.add(r.id);
        if (r.result.state === 'paid') paidMap.set(r.id, r.result.transaction);
      }

      activeTransactions = list
        .filter((t) => !deletedIds.has(t.id))
        .map((t) => paidMap.get(t.id) || t);
    }

    return NextResponse.json(
      {
        status: 'success',
        data: activeTransactions,
      },
      {
        headers: {
          'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0',
          Pragma: 'no-cache',
          Expires: '0',
        },
      }
    );
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
