import crypto from 'crypto';
import { supabaseAdmin } from './supabase';
import { IntegrationSettings } from './settings';

export function getRequestOrigin(req: Request): string {
  const forwardedHost = req.headers.get('x-forwarded-host')?.split(',')[0]?.trim();
  const forwardedProto = req.headers.get('x-forwarded-proto')?.split(',')[0]?.trim();
  if (forwardedHost) {
    const proto = forwardedProto || 'https';
    return `${proto}://${forwardedHost}`;
  }
  const host = req.headers.get('host')?.trim();
  if (host) {
    const isLocal = host.includes('localhost') || host.startsWith('127.0.0.1');
    const proto = forwardedProto || (isLocal ? 'http' : 'https');
    return `${proto}://${host}`;
  }
  return new URL(req.url).origin;
}

export function isPharmacyPaymentMethod(method?: string | null): boolean {
  return method === 'pharmacy' || method === 'bayar_di_apotek';
}

export function isMidtransStatusPaid(midtransData: any): boolean {
  const tStatus = midtransData?.transaction_status;
  const fStatus = midtransData?.fraud_status;
  return (
    tStatus === 'settlement' ||
    (tStatus === 'capture' && (!fStatus || fStatus === 'accept'))
  );
}

export function isMidtransStatusExpiredOrFailed(midtransData: any): boolean {
  const tStatus = midtransData?.transaction_status;
  return ['expire', 'cancel', 'deny'].includes(tStatus);
}

export function mapMidtransPaymentMethod(
  paymentType?: string | null,
  fallback = 'qris'
): string {
  if (!paymentType) return fallback;
  if (['qris', 'gopay', 'shopeepay'].includes(paymentType)) return 'qris';
  if (['credit_card', 'card'].includes(paymentType)) return 'kartu';
  if (['bank_transfer', 'echannel', 'permata_va', 'cstore'].includes(paymentType)) {
    return 'va';
  }
  return fallback;
}

export function extractMidtransPaymentDetails(midtransData: any) {
  let bankName: string | null = null;
  let vaNumber: string | null = null;
  let billKey: string | null = null;
  let billerCode: string | null = null;
  let qrUrl: string | null = null;

  if (
    midtransData?.va_numbers &&
    Array.isArray(midtransData.va_numbers) &&
    midtransData.va_numbers.length > 0
  ) {
    bankName = midtransData.va_numbers[0].bank?.toUpperCase() || null;
    vaNumber = midtransData.va_numbers[0].va_number || null;
  } else if (midtransData?.permata_va_number) {
    bankName = 'PERMATA';
    vaNumber = midtransData.permata_va_number;
  } else if (midtransData?.bill_key && midtransData?.biller_code) {
    bankName = 'MANDIRI';
    billKey = midtransData.bill_key;
    billerCode = midtransData.biller_code;
  }

  if (midtransData?.actions && Array.isArray(midtransData.actions)) {
    const qrAct = midtransData.actions.find(
      (a: any) => a.name === 'generate-qr-code'
    );
    if (qrAct) {
      qrUrl = qrAct.url;
    }
  }

  return {
    payment_type: midtransData?.payment_type || null,
    bank_name: bankName,
    va_number: vaNumber,
    bill_key: billKey,
    biller_code: billerCode,
    qr_url: qrUrl,
    expiry_time: midtransData?.expiry_time || null,
  };
}

/**
 * Permanently deletes an unpaid/expired/failed/cancelled transaction and its items.
 * Guarded by status so paid/completed orders are never deleted.
 */
export async function deletePendingTransaction(trxId: number): Promise<boolean> {
  const { data: deleted, error } = await supabaseAdmin
    .from('transactions')
    .delete()
    .eq('id', trxId)
    .in('status', ['pending', 'expired', 'gagal', 'dibatalkan'])
    .select('id')
    .maybeSingle();

  if (error || !deleted) {
    return false;
  }

  // Cleanup items explicitly in case cascade is not configured in an existing DB
  await supabaseAdmin.from('transaction_items').delete().eq('transaction_id', trxId);
  return true;
}

export async function markTransactionPaidFromMidtrans(
  trx: any,
  midtransData: any
): Promise<any | null> {
  const qrToken =
    trx.qr_token || 'PKP-' + crypto.randomBytes(12).toString('hex').toUpperCase();
  const mappedMethod = mapMidtransPaymentMethod(
    midtransData?.payment_type,
    trx.payment_method || 'qris'
  );

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

  return updated;
}

export async function syncAndCleanPendingMidtransOrder(
  trx: any,
  settings: IntegrationSettings
): Promise<
  | { state: 'paid'; transaction: any }
  | { state: 'deleted' }
  | { state: 'pending'; paymentDetails: any }
> {
  if (['expired', 'gagal', 'dibatalkan'].includes(trx.status)) {
    await deletePendingTransaction(trx.id);
    return { state: 'deleted' };
  }

  if (trx.status !== 'pending' || isPharmacyPaymentMethod(trx.payment_method)) {
    return { state: 'pending', paymentDetails: null };
  }

  const serverKey = (settings.midtransServerKey || '').trim();
  if (!serverKey || serverKey.includes('demo')) {
    return { state: 'pending', paymentDetails: null };
  }

  const statusBaseUrl = settings.midtransIsProduction
    ? 'https://api.midtrans.com'
    : 'https://api.sandbox.midtrans.com';
  const authHeader = 'Basic ' + Buffer.from(`${serverKey}:`).toString('base64');

  try {
    const midtransRes = await fetch(
      `${statusBaseUrl}/v2/${encodeURIComponent(trx.invoice_no)}/status`,
      {
        method: 'GET',
        headers: {
          Accept: 'application/json',
          Authorization: authHeader,
        },
        cache: 'no-store',
      }
    );

    if (midtransRes.ok) {
      const midtransData = await midtransRes.json();

      if (midtransData?.status_code === '404') {
        return { state: 'pending', paymentDetails: null };
      }

      if (isMidtransStatusPaid(midtransData)) {
        const updated = await markTransactionPaidFromMidtrans(trx, midtransData);
        if (updated) {
          return { state: 'paid', transaction: updated };
        }
        const { data: latest } = await supabaseAdmin
          .from('transactions')
          .select('*, items:transaction_items(*)')
          .eq('id', trx.id)
          .maybeSingle();
        return { state: 'paid', transaction: latest || { ...trx, status: 'paid' } };
      }

      if (isMidtransStatusExpiredOrFailed(midtransData)) {
        await deletePendingTransaction(trx.id);
        return { state: 'deleted' };
      }

      return {
        state: 'pending',
        paymentDetails: extractMidtransPaymentDetails(midtransData),
      };
    }
  } catch (err) {
    console.error('[syncAndCleanPendingMidtransOrder error]', err);
  }

  return { state: 'pending', paymentDetails: null };
}
