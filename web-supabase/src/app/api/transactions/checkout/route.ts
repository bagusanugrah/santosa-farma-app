import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';

export async function POST(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json({ status: 'error', message: 'Silakan login terlebih dahulu.' }, { status: 401 });
    }

    // 1. Verify store status
    const { data: storeSetting } = await supabaseAdmin
      .from('store_settings')
      .select('is_open, online_orders_enabled')
      .eq('id', 1)
      .maybeSingle();

    if (!storeSetting?.is_open) {
      return NextResponse.json(
        { status: 'error', message: 'Apotek Santosa Farma saat ini sedang tutup. Pemesanan tidak dapat diproses.' },
        { status: 403 }
      );
    }

    if (!storeSetting?.online_orders_enabled) {
      return NextResponse.json(
        { status: 'error', message: 'Fitur pemesanan online dinonaktifkan oleh kasir toko.' },
        { status: 403 }
      );
    }

    const body = await req.json();
    const { items } = body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return NextResponse.json({ status: 'error', message: 'Keranjang belanja kosong.' }, { status: 422 });
    }

    // 2. Fetch products and check stock
    const productIds = items.map((i: any) => i.product_id);
    const { data: products, error: prodErr } = await supabaseAdmin
      .from('products')
      .select('*')
      .in('id', productIds);

    if (prodErr || !products) {
      return NextResponse.json({ status: 'error', message: 'Gagal memverifikasi obat.' }, { status: 500 });
    }

    const productMap = new Map<number, any>();
    products.forEach((p) => productMap.set(p.id, p));

    let grandTotal = 0;
    const orderItems: Array<{
      product_id: number;
      product_name: string;
      qty: number;
      price: number;
      subtotal: number;
    }> = [];

    for (const item of items) {
      const prod = productMap.get(item.product_id);
      if (!prod) {
        return NextResponse.json(
          { status: 'error', message: `Obat ID ${item.product_id} tidak ditemukan.` },
          { status: 422 }
        );
      }
      if (prod.stock < item.qty) {
        return NextResponse.json(
          { status: 'error', message: `Stok obat '${prod.name}' tidak mencukupi (Tersisa: ${prod.stock}).` },
          { status: 422 }
        );
      }

      const price = Number(prod.price);
      const subtotal = price * item.qty;
      grandTotal += subtotal;

      orderItems.push({
        product_id: prod.id,
        product_name: prod.name,
        qty: item.qty,
        price,
        subtotal,
      });
    }

    // 3. Generate unique invoice number: INV-YYYYMMDD-XXXX
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const randomSuffix = Math.floor(1000 + Math.random() * 9000).toString();
    const invoiceNo = `INV-${dateStr}-${randomSuffix}`;

    // 4. Insert transaction
    const { data: newTrx, error: trxErr } = await supabaseAdmin
      .from('transactions')
      .insert({
        invoice_no: invoiceNo,
        channel: 'online',
        customer_id: customer.id,
        payment_method: 'qris',
        status: 'pending',
        total: grandTotal,
      })
      .select()
      .single();

    if (trxErr || !newTrx) {
      return NextResponse.json(
        { status: 'error', message: trxErr?.message || 'Gagal menyimpan transaksi.' },
        { status: 500 }
      );
    }

    // 5. Insert transaction items
    const itemsToInsert = orderItems.map((item) => ({
      transaction_id: newTrx.id,
      product_id: item.product_id,
      product_name: item.product_name,
      qty: item.qty,
      price: item.price,
      subtotal: item.subtotal,
    }));

    const { error: itemsErr } = await supabaseAdmin
      .from('transaction_items')
      .insert(itemsToInsert);

    if (itemsErr) {
      console.error('Error inserting transaction items:', itemsErr);
    }

    // 6. Request Midtrans Snap Token
    let snapToken = null;
    const midtransServerKey = process.env.MIDTRANS_SERVER_KEY || 'SB-Mid-server-demo';
    const isProd = process.env.MIDTRANS_IS_PRODUCTION === 'true';
    const snapEndpoint = isProd
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

    if (!midtransServerKey.includes('demo')) {
      try {
        const midtransPayload = {
          transaction_details: {
            order_id: invoiceNo,
            gross_amount: Math.round(grandTotal),
          },
          item_details: orderItems.map((i) => ({
            id: String(i.product_id),
            price: Math.round(i.price),
            quantity: i.qty,
            name: i.product_name.substring(0, 50),
          })),
          customer_details: {
            first_name: customer.name,
            email: customer.email || 'pelanggan@santosa.id',
            phone: customer.phone || '08123456789',
          },
        };

        const authHeader = 'Basic ' + Buffer.from(`${midtransServerKey}:`).toString('base64');
        const snapRes = await fetch(snapEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            Authorization: authHeader,
          },
          body: JSON.stringify(midtransPayload),
        });

        if (snapRes.ok) {
          const snapData = await snapRes.json();
          snapToken = snapData.token;
        } else {
          console.warn('[Midtrans Snap API Warning]', await snapRes.text());
        }
      } catch (err) {
        console.warn('[Midtrans Snap Fetch Exception]', err);
      }
    }

    // Fallback mock token if demo or network error
    if (!snapToken) {
      snapToken = `mock-snap-${invoiceNo}-${crypto.randomBytes(6).toString('hex')}`;
    }

    // Update snap token in transaction record
    await supabaseAdmin
      .from('transactions')
      .update({ midtrans_snap_token: snapToken })
      .eq('id', newTrx.id);

    return NextResponse.json({
      status: 'success',
      message: 'Pesanan berhasil dibuat.',
      data: {
        transaction: {
          ...newTrx,
          midtrans_snap_token: snapToken,
          items: orderItems,
        },
        snap_token: snapToken,
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
