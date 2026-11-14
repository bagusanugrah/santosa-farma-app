import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { supabaseAdmin } from '@/lib/supabase';

export async function POST(req: Request) {
  try {
    const payload = await req.json();
    console.log('[Midtrans Webhook Received]', payload);

    const orderId = payload.order_id;
    const statusCode = payload.status_code;
    const grossAmount = payload.gross_amount;
    const signatureKey = payload.signature_key;
    const transactionStatus = payload.transaction_status;
    const fraudStatus = payload.fraud_status;
    const paymentType = payload.payment_type;

    if (!orderId) {
      return NextResponse.json({ status: 'error', message: 'Missing order_id' }, { status: 400 });
    }

    // Verify signature key if present and server key is not demo
    const serverKey = process.env.MIDTRANS_SERVER_KEY || '';
    if (signatureKey && !serverKey.includes('demo')) {
      const hash = crypto
        .createHash('sha512')
        .update(orderId + statusCode + grossAmount + serverKey)
        .digest('hex');

      if (hash !== signatureKey) {
        console.warn('[Midtrans Webhook] Invalid signature key for order:', orderId);
        return NextResponse.json({ status: 'error', message: 'Invalid signature key' }, { status: 403 });
      }
    }

    // Find transaction
    const { data: transaction, error: findErr } = await supabaseAdmin
      .from('transactions')
      .select('*, items:transaction_items(*)')
      .eq('invoice_no', orderId)
      .maybeSingle();

    if (findErr || !transaction) {
      console.warn('[Midtrans Webhook] Transaction not found:', orderId);
      return NextResponse.json({ status: 'error', message: 'Transaction not found' }, { status: 404 });
    }

    // Map payment method
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

    // Extract VA number if any
    let vaNumber = null;
    if (payload.va_numbers && payload.va_numbers[0]) {
      vaNumber = `${payload.va_numbers[0].bank}: ${payload.va_numbers[0].va_number}`;
    } else if (payload.permata_va_number) {
      vaNumber = `Permata: ${payload.permata_va_number}`;
    } else if (payload.bill_key) {
      vaNumber = `Mandiri: ${payload.bill_key}`;
    }

    const isPaid =
      transactionStatus === 'settlement' ||
      (transactionStatus === 'capture' && fraudStatus === 'accept');

    if (isPaid) {
      const alreadyPaid = ['paid', 'selesai', 'diambil'].includes(transaction.status);
      if (!alreadyPaid) {
        // Generate pickup QR token
        const qrToken = 'PKP-' + crypto.randomBytes(12).toString('hex').toUpperCase();

        // Update transaction to paid
        await supabaseAdmin
          .from('transactions')
          .update({
            status: 'paid',
            payment_method: mappedMethod,
            midtrans_va_number: vaNumber || transaction.midtrans_va_number,
            paid_at: new Date().toISOString(),
            qr_token: qrToken,
          })
          .eq('id', transaction.id);

        // Deduct product stocks
        if (transaction.items && Array.isArray(transaction.items)) {
          for (const item of transaction.items) {
            if (item.product_id) {
              const { data: prod } = await supabaseAdmin
                .from('products')
                .select('stock')
                .eq('id', item.product_id)
                .single();

              if (prod) {
                const newStock = Math.max(0, prod.stock - item.qty);
                await supabaseAdmin
                  .from('products')
                  .update({ stock: newStock })
                  .eq('id', item.product_id);
              }
            }
          }
        }
      }
    } else if (transactionStatus === 'pending') {
      await supabaseAdmin
        .from('transactions')
        .update({
          status: 'pending',
          payment_method: mappedMethod,
          midtrans_va_number: vaNumber || transaction.midtrans_va_number,
        })
        .eq('id', transaction.id);
    } else if (['deny', 'cancel', 'expire'].includes(transactionStatus)) {
      const newStatus = transactionStatus === 'expire' ? 'expired' : 'gagal';
      await supabaseAdmin
        .from('transactions')
        .update({ status: newStatus })
        .eq('id', transaction.id);
    }

    return NextResponse.json({
      status: 'success',
      message: 'Notification processed successfully',
    });
  } catch (err: any) {
    console.error('Midtrans Webhook Error:', err);
    return NextResponse.json(
      { status: 'error', message: err.message || 'Server error' },
      { status: 500 }
    );
  }
}
