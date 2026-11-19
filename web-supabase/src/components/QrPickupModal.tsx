'use client';

import React from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { X, QrCode, Download, CheckCircle2 } from 'lucide-react';
import { Transaction } from '@/lib/api';

interface QrPickupModalProps {
  isOpen: boolean;
  onClose: () => void;
  transaction: Transaction | null;
}

export default function QrPickupModal({ isOpen, onClose, transaction }: QrPickupModalProps) {
  if (!isOpen || !transaction) return null;

  const qrValue = transaction.qr_token || transaction.invoice_no;
  const isPayAtStore = transaction.payment_method === 'pharmacy' || transaction.status === 'pending';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
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
            onClick={() => window.print()}
            className="w-full py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition flex items-center justify-center space-x-1"
          >
            <Download className="w-4 h-4" />
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
  );
}

