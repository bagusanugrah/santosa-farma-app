'use client';

import React, { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { X, QrCode, Printer, CheckCircle2 } from 'lucide-react';
import { Transaction, TransactionItem } from '@/lib/api';
import { supabase } from '@/lib/supabase';

interface QrPickupModalProps {
  isOpen: boolean;
  onClose: () => void;
  transaction: Transaction | null;
}

export default function QrPickupModal({ isOpen, onClose, transaction }: QrPickupModalProps) {
  const [items, setItems] = useState<TransactionItem[]>(transaction?.items || []);

  useEffect(() => {
    if (transaction) {
      if (!transaction.items || transaction.items.length === 0) {
        supabase
          .from('transaction_items')
          .select('*')
          .eq('transaction_id', transaction.id)
          .then(({ data }) => {
            if (data && data.length > 0) {
              setItems(data as any);
            }
          });
      } else {
        setItems(transaction.items);
      }
    }
  }, [transaction]);

  if (!isOpen || !transaction) return null;

  const qrValue = transaction.qr_token || transaction.invoice_no;
  const isPayAtStore = transaction.payment_method === 'pharmacy' || transaction.status === 'pending';

  const handlePrint = () => {
    window.print();
  };

  const formattedDate = new Date(transaction.created_at).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Asia/Jakarta',
  });

  return (
    <>
      {/* Print Stylesheet: Ensures ONLY #pickup-print-slip prints and fills the page */}
      <style jsx global>{`
        @media print {
          @page {
            size: auto;
            margin: 10mm 15mm;
          }
          html, body {
            background: #ffffff !important;
            color: #000000 !important;
            margin: 0 !important;
            padding: 0 !important;
            width: 100% !important;
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
          }
          body * {
            visibility: hidden !important;
          }
          #pickup-print-slip,
          #pickup-print-slip * {
            visibility: visible !important;
          }
          #pickup-print-slip {
            position: absolute !important;
            left: 0 !important;
            top: 0 !important;
            width: 100% !important;
            display: block !important;
            margin: 0 !important;
            padding: 0 !important;
            background: #ffffff !important;
            box-shadow: none !important;
            border: none !important;
          }
        }
      `}</style>

      {/* =========================================================================
          1. INTERACTIVE SCREEN MODAL (Hidden when printing via print:hidden)
          ========================================================================= */}
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm print:hidden">
        <div className="bg-white rounded-3xl max-w-sm w-full p-6 shadow-2xl relative animate-scale text-center">
          <button
            onClick={onClose}
            className="absolute top-5 right-5 text-slate-400 hover:text-slate-700 p-1.5 rounded-full hover:bg-slate-100 transition"
          >
            <X className="w-5 h-5" />
          </button>

          <div className="w-12 h-12 rounded-2xl bg-brand-50 text-brand-600 flex items-center justify-center mx-auto mb-3 shadow-inner">
            <QrCode className="w-6 h-6" />
          </div>

          <h3 className="text-lg font-bold text-slate-900">
            {isPayAtStore ? 'QR Pesanan Bayar di Apotek' : 'QR Pengambilan Obat'}
          </h3>
          <p className="text-xs text-slate-500 mt-1">
            {isPayAtStore
              ? 'Perlihatkan QR code ini ke kasir saat tiba di Apotek Santosa Farma untuk pengecekan pesanan dan pembayaran (Tunai / QRIS).'
              : 'Tunjukkan QR code ini ke kasir Apotek Santosa Farma untuk mengambil pesanan Anda yang sudah lunas.'}
          </p>

          {/* QR Code Container */}
          <div className="my-5 p-4 bg-white rounded-2xl border-2 border-dashed border-brand-300 inline-block shadow-sm">
            <QRCodeSVG
              value={qrValue}
              size={190}
              level="H"
              includeMargin={true}
            />
          </div>

          <div className="bg-slate-50 p-3.5 rounded-2xl border border-slate-100 text-left space-y-1.5 text-xs">
            <div className="flex justify-between">
              <span className="text-slate-500">No. Invoice:</span>
              <span className="font-bold text-slate-800 font-mono">{transaction.invoice_no}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Metode:</span>
              <span className="font-bold text-brand-700">
                {isPayAtStore ? 'Bayar di Kasir (Apotek)' : 'Online (Midtrans)'}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Status:</span>
              <span className={`font-bold uppercase ${isPayAtStore ? 'text-amber-600' : 'text-emerald-600'}`}>
                {isPayAtStore ? 'Menunggu Bayar di Kasir' : transaction.status}
              </span>
            </div>
            <div className="flex justify-between pt-1 border-t border-slate-200">
              <span className="text-slate-500">Estimasi Total:</span>
              <span className="font-extrabold text-slate-900">Rp {Number(transaction.total).toLocaleString('id-ID')}</span>
            </div>
          </div>

          <div className="mt-5 space-y-2">
            <button
              onClick={handlePrint}
              className="w-full py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition flex items-center justify-center space-x-1.5"
            >
              <Printer className="w-4 h-4" />
              <span>Cetak Bukti Pesanan</span>
            </button>
            <button
              onClick={onClose}
              className="w-full py-3 bg-brand-600 hover:bg-brand-700 text-white font-bold text-xs rounded-xl transition shadow-md shadow-brand-600/20"
            >
              Lihat di Daftar Pesanan
            </button>
          </div>
        </div>
      </div>

      {/* =========================================================================
          2. DEDICATED PRINT CARD (Hidden on screen, visible ONLY when printed)
             Fills 1 full page cleanly without giant empty voids or popup shadows.
          ========================================================================= */}
      <div id="pickup-print-slip" className="hidden print:block text-slate-900 font-sans">
        {/* Header Apotek */}
        <div className="border-b-2 border-slate-900 pb-3 flex items-start justify-between">
          <div>
            <h1 className="text-xl font-black tracking-wide text-slate-900 uppercase">
              Apotek Santosa Farma
            </h1>
            <p className="text-xs text-slate-600 mt-0.5">
              Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat 41281
            </p>
            <p className="text-xs text-slate-600">
              Telepon: (0260) 123456 | WhatsApp: 0877-7403-8395
            </p>
          </div>
          <div className="text-right">
            <div className="inline-block px-3 py-1 bg-slate-100 border border-slate-300 rounded-lg text-xs font-black uppercase tracking-wider text-slate-900">
              {isPayAtStore ? 'Bukti Pemesanan (Bayar di Kasir)' : 'Bukti Pengambilan Obat (Lunas)'}
            </div>
            <p className="text-[11px] font-mono font-bold text-slate-600 mt-1">
              {transaction.invoice_no}
            </p>
          </div>
        </div>

        {/* Info Grid (2 Columns) */}
        <div className="my-3.5 grid grid-cols-2 gap-4 text-xs bg-slate-50 p-3.5 rounded-xl border border-slate-200">
          <div className="space-y-1">
            <div className="flex">
              <span className="w-28 text-slate-500">No. Invoice:</span>
              <span className="font-bold text-slate-900 font-mono">{transaction.invoice_no}</span>
            </div>
            <div className="flex">
              <span className="w-28 text-slate-500">Waktu Pesan:</span>
              <span className="text-slate-800 font-medium">{formattedDate} WIB</span>
            </div>
            <div className="flex">
              <span className="w-28 text-slate-500">Tipe Pesanan:</span>
              <span className="text-slate-800 font-medium uppercase">Pemesanan Online Web</span>
            </div>
          </div>
          <div className="space-y-1">
            <div className="flex">
              <span className="w-28 text-slate-500">Metode Bayar:</span>
              <span className="font-bold text-slate-900">
                {isPayAtStore ? 'Bayar di Kasir (Apotek)' : 'Online (Midtrans)'}
              </span>
            </div>
            <div className="flex">
              <span className="w-28 text-slate-500">Status Pembayaran:</span>
              <span className={`font-black uppercase ${isPayAtStore ? 'text-amber-700' : 'text-emerald-700'}`}>
                {isPayAtStore ? 'MENUNGGU BAYAR DI KASIR' : 'LUNAS (SIAP DIAMBIL)'}
              </span>
            </div>
            <div className="flex">
              <span className="w-28 text-slate-500">Kode Token:</span>
              <span className="font-mono font-bold text-slate-900">{qrValue}</span>
            </div>
          </div>
        </div>

        {/* Box QR Code & Petunjuk Kasir */}
        <div className="my-3.5 p-4 border-2 border-dashed border-slate-300 rounded-2xl flex items-center justify-between gap-6 bg-slate-50/60">
          <div className="space-y-1.5 flex-1 text-xs">
            <h3 className="font-extrabold text-slate-900 text-sm tracking-wide">
              KODE QR PENGAMBILAN OBAT
            </h3>
            <p className="text-slate-600 leading-relaxed text-[11px]">
              {isPayAtStore
                ? 'Tunjukkan kode QR ini ke petugas kasir saat tiba di Apotek Santosa Farma untuk verifikasi obat dan penyelesaian pembayaran (Tunai / QRIS).'
                : 'Tunjukkan kode QR ini ke petugas kasir Apotek Santosa Farma untuk mengambil pesanan Anda yang sudah lunas tanpa perlu antre pembayaran ulang.'}
            </p>
            <div className="pt-1 flex items-center space-x-2">
              <span className="text-[11px] text-slate-500 font-medium">Token Pengambilan:</span>
              <span className="font-mono text-xs font-black text-slate-900 tracking-wider bg-white px-2.5 py-0.5 rounded border border-slate-300">
                {qrValue}
              </span>
            </div>
          </div>

          {/* QR Code SVG */}
          <div className="bg-white p-2.5 rounded-xl border border-slate-300 shadow-sm flex-shrink-0 text-center">
            <QRCodeSVG value={qrValue} size={135} level="H" includeMargin={false} />
            <span className="text-[9px] font-mono font-bold text-slate-500 block mt-1 tracking-wider">
              SCAN QR KASIR
            </span>
          </div>
        </div>

        {/* Tabel Rincian Obat */}
        <div className="my-3.5">
          <h4 className="text-xs font-bold text-slate-800 uppercase tracking-wider mb-2">
            Rincian Obat yang Dipesan
          </h4>
          <table className="w-full text-xs border-collapse">
            <thead>
              <tr className="border-b-2 border-slate-900 bg-slate-100 text-slate-800 font-bold">
                <th className="py-2 px-2 text-left w-8">No</th>
                <th className="py-2 px-2 text-left">Nama Obat / Produk</th>
                <th className="py-2 px-2 text-center w-16">Jumlah</th>
                <th className="py-2 px-2 text-right w-28">Harga Satuan</th>
                <th className="py-2 px-2 text-right w-28">Subtotal</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {items && items.length > 0 ? (
                items.map((item, idx) => (
                  <tr key={item.id || idx}>
                    <td className="py-2 px-2 text-slate-500 text-center">{idx + 1}</td>
                    <td className="py-2 px-2 font-semibold text-slate-900">{item.product_name}</td>
                    <td className="py-2 px-2 text-center font-bold text-slate-800">{item.qty}</td>
                    <td className="py-2 px-2 text-right text-slate-700">Rp {Number(item.price).toLocaleString('id-ID')}</td>
                    <td className="py-2 px-2 text-right font-bold text-slate-900">Rp {Number(item.subtotal).toLocaleString('id-ID')}</td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="py-3 text-center text-slate-400">
                    Rincian obat tidak tersedia
                  </td>
                </tr>
              )}
            </tbody>
            <tfoot>
              <tr className="border-t-2 border-slate-900">
                <td colSpan={4} className="py-2.5 px-2 text-right font-extrabold text-sm text-slate-900">
                  TOTAL PEMBAYARAN:
                </td>
                <td className="py-2.5 px-2 text-right font-black text-sm text-slate-900">
                  Rp {Number(transaction.total).toLocaleString('id-ID')}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>

        {/* Catatan Pengambilan & Watermark */}
        <div className="mt-4 pt-3 border-t border-slate-300 text-[11px] text-slate-500 flex justify-between items-end">
          <div className="space-y-0.5">
            <p className="font-bold text-slate-800">Ketentuan Pengambilan:</p>
            <p>1. Harap bawa dan tunjukkan lembar cetak ini atau kode QR di atas ke kasir apotek.</p>
            <p>2. Pastikan memeriksa kembali nama obat, dosis, dan segel kemasan saat pengambilan.</p>
            <p>3. Bukti pemesanan ini sah tercatat di sistem informasi Apotek Santosa Farma.</p>
          </div>
          <div className="text-right text-[10px] text-slate-400">
            <p>Dicetak otomatis oleh Sistem Santosa Farma</p>
            <p>{new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' })} WIB</p>
          </div>
        </div>
      </div>
    </>
  );
}
