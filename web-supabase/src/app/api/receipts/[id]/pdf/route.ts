import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

export async function GET(req: Request, { params }: { params: { id: string } }) {
  try {
    const id = params.id;
    const { data: transaction, error } = await supabaseAdmin
      .from('transactions')
      .select('*, items:transaction_items(*), customer:customers(*)')
      .eq('id', id)
      .maybeSingle();

    if (error || !transaction) {
      return new NextResponse('Struk tidak ditemukan.', { status: 404 });
    }

    const itemsHtml = (transaction.items || [])
      .map(
        (item: any) => `
      <tr>
        <td style="padding: 6px 0; border-bottom: 1px dashed #e2e8f0;">
          <div style="font-weight: 600; color: #1e293b;">${item.product_name}</div>
          <div style="font-size: 11px; color: #64748b;">${item.qty} x Rp ${Number(item.price).toLocaleString('id-ID')}</div>
        </td>
        <td style="padding: 6px 0; text-align: right; font-weight: 700; color: #1e293b; border-bottom: 1px dashed #e2e8f0;">
          Rp ${Number(item.subtotal).toLocaleString('id-ID')}
        </td>
      </tr>
    `
      )
      .join('');

    const formattedDate = new Date(transaction.created_at).toLocaleDateString('id-ID', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });

    const html = `
    <!DOCTYPE html>
    <html lang="id">
    <head>
      <meta charset="UTF-8">
      <title>Struk Pembelian - ${transaction.invoice_no}</title>
      <style>
        @page {
          size: 80mm auto;
          margin: 0;
        }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          font-size: 12px;
          color: #1e293b;
          margin: 0;
          padding: 16px;
          background: #f8fafc;
        }
        .receipt-card {
          max-width: 380px;
          margin: 0 auto;
          background: #ffffff;
          padding: 24px;
          border-radius: 16px;
          box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
        }
        @media print {
          body { background: #fff; padding: 0; }
          .receipt-card { box-shadow: none; border-radius: 0; max-width: 100%; padding: 8px; }
          .no-print { display: none; }
        }
      </style>
    </head>
    <body>
      <div class="receipt-card">
        <div style="text-align: center; margin-bottom: 16px;">
          <div style="font-size: 16px; font-weight: 800; color: #047857; text-transform: uppercase; letter-spacing: 0.5px;">Apotek Santosa Farma</div>
          <div style="font-size: 11px; color: #64748b; margin-top: 2px;">Jl. Raya Jalancagak, Subang, Jawa Barat</div>
          <div style="font-size: 11px; color: #64748b;">WhatsApp: 0812-3456-7890</div>
        </div>

        <div style="border-top: 2px dashed #cbd5e1; border-bottom: 2px dashed #cbd5e1; padding: 10px 0; margin-bottom: 16px; font-size: 11px;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span style="color: #64748b;">No. Invoice:</span>
            <span style="font-weight: 700;">${transaction.invoice_no}</span>
          </div>
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span style="color: #64748b;">Waktu:</span>
            <span>${formattedDate}</span>
          </div>
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span style="color: #64748b;">Pelanggan:</span>
            <span>${transaction.customer?.name || 'Pelanggan Online'}</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span style="color: #64748b;">Metode Bayar:</span>
            <span style="font-weight: 700; text-transform: uppercase;">${transaction.payment_method || 'Online (QRIS)'}</span>
          </div>
        </div>

        <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
          <tbody>
            ${itemsHtml}
          </tbody>
        </table>

        <div style="border-top: 1px solid #e2e8f0; padding-top: 10px; margin-bottom: 20px;">
          <div style="display: flex; justify-content: space-between; font-size: 14px; font-weight: 800;">
            <span>TOTAL:</span>
            <span style="color: #047857;">Rp ${Number(transaction.total).toLocaleString('id-ID')}</span>
          </div>
          <div style="display: flex; justify-content: space-between; font-size: 11px; color: #10b981; margin-top: 4px; font-weight: 600;">
            <span>Status:</span>
            <span>LUNAS (${transaction.status.toUpperCase()})</span>
          </div>
        </div>

        <div style="text-align: center; border-top: 2px dashed #cbd5e1; padding-top: 16px; font-size: 11px; color: #64748b;">
          <div>Terima kasih atas kunjungan & kepercayaan Anda!</div>
          <div style="margin-top: 4px; font-weight: 600; color: #047857;">Semoga Lekas Sembuh & Sehat Selalu</div>
        </div>

        <div class="no-print" style="margin-top: 24px; text-align: center;">
          <button onclick="window.print()" style="padding: 10px 24px; background: #059669; color: white; border: none; border-radius: 12px; font-weight: bold; cursor: pointer; font-size: 12px;">
            Cetak Struk Ini
          </button>
        </div>
      </div>
      <script>
        window.onload = function() {
          // If query param ?autoprint=1, open print dialog
          if (window.location.search.includes('autoprint=1')) {
            window.print();
          }
        }
      </script>
    </body>
    </html>
    `;

    return new NextResponse(html, {
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
      },
    });
  } catch (err: any) {
    return new NextResponse('Terjadi kesalahan: ' + err.message, { status: 500 });
  }
}
