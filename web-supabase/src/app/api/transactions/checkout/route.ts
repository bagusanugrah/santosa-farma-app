import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';
import { getIntegrationSettings } from '@/lib/settings';

export async function POST(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json({ status: 'error', message: 'Silakan login terlebih dahulu.' }, { status: 401 });
    }

    // 1. Verify store status and Midtrans credentials
    const { data: storeSetting } = await supabaseAdmin
      .from('store_settings')
      .select('is_open, online_orders_enabled, midtrans_client_key, midtrans_server_key')
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
    const { items, payment_method } = body;

    // payment_method can be 'pharmacy' (Bayar di Apotek) or 'midtrans'
    const isPharmacyPickup = payment_method === 'pharmacy' || payment_method === 'bayar_di_apotek';

    const midClient = (storeSetting?.midtrans_client_key || '').trim();
    const midServer = (storeSetting?.midtrans_server_key || '').trim();
    const hasValidMidtrans = midClient.length >= 15 && midServer.length >= 15;

    if (!isPharmacyPickup && !hasValidMidtrans) {
      return NextResponse.json(
        {
          status: 'error',
          message:
            'Metode pembayaran online (Midtrans) belum dikonfigurasi secara valid. Silakan gunakan metode Bayar di Apotek.',
        },
        { status: 403 }
      );
    }

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
      const qty = parseInt(String(item.qty), 10);
      if (!Number.isFinite(qty) || qty <= 0) {
        return NextResponse.json(
          { status: 'error', message: 'Jumlah pesanan obat harus minimal 1.' },
          { status: 422 }
        );
      }

      const prod = productMap.get(Number(item.product_id));
      if (!prod) {
        return NextResponse.json(
          { status: 'error', message: `Obat ID ${item.product_id} tidak ditemukan.` },
          { status: 422 }
        );
      }
      if (prod.stock < qty) {
        return NextResponse.json(
          { status: 'error', message: `Stok obat '${prod.name}' tidak mencukupi (Tersisa: ${prod.stock}).` },
          { status: 422 }
        );
      }

      const price = Number(prod.price);
      const subtotal = price * qty;
      grandTotal += subtotal;

      orderItems.push({
        product_id: prod.id,
        product_name: prod.name,
        qty,
        price,
        subtotal,
      });
    }

    // 3. Generate unique invoice number: INV-YYYYMMDD-XXXX
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const randomSuffix = Math.floor(1000 + Math.random() * 9000).toString();
    const invoiceNo = `INV-${dateStr}-${randomSuffix}`;
    const qrToken = `SF-${dateStr}-${randomSuffix}`;

    // 4. Insert transaction
    const { data: newTrx, error: trxErr } = await supabaseAdmin
      .from('transactions')
      .insert({
        invoice_no: invoiceNo,
        channel: 'online',
        customer_id: customer.id,
        payment_method: isPharmacyPickup ? 'pharmacy' : 'qris',
        status: 'pending',
        total: grandTotal,
        qr_token: qrToken,
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

    // If customer chose "Bayar di Apotek", return immediately with the QR code and transaction
    if (isPharmacyPickup) {
      return NextResponse.json({
        status: 'success',
        message: 'Pesanan berhasil dibuat. Tunjukkan QR pesanan ke kasir Apotek Santosa Farma untuk pembayaran.',
        data: {
          transaction: {
            ...newTrx,
            qr_token: qrToken,
            items: orderItems,
          },
          snap_token: null,
          is_pharmacy_pickup: true,
        },
      });
    }

    // 6. Request Midtrans Snap Token
    const settings = await getIntegrationSettings();
    const midtransServerKey = (settings.midtransServerKey || storeSetting.midtrans_server_key || '').trim();
    const isProd = settings.midtransIsProduction;
    const snapEndpoint = isProd
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

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

    let snapToken = null;
    try {
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
        const errText = await snapRes.text();
        console.error('[Midtrans Snap API Error]', errText);
      }
    } catch (err) {
      console.error('[Midtrans Snap Fetch Exception]', err);
    }

    // If Midtrans failed or rejected credentials, rollback transaction to prevent invalid state
    if (!snapToken) {
      await supabaseAdmin.from('transaction_items').delete().eq('transaction_id', newTrx.id);
      await supabaseAdmin.from('transactions').delete().eq('id', newTrx.id);
      return NextResponse.json(
        {
          status: 'error',
          message:
            'Gagal menghubungi gateway pembayaran Midtrans. Pastikan kredensial Midtrans di Pengaturan Toko valid dan sesuai mode (Sandbox/Production).',
        },
        { status: 502 }
      );
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
