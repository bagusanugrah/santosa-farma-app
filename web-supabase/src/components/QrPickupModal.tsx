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

        <h3 className="text-lg font-bold text-slate-900">QR Pengambilan Obat</h3>
        <p className="text-xs text-slate-500 mt-1">Tunjukkan QR code ini ke kasir Apotek Santosa Farma untuk mengambil pesanan Anda.</p>

        {/* QR Code Container */}
        <div className="my-5 p-4 bg-white rounded-2xl border-2 border-dashed border-slate-200 inline-block shadow-sm">
          <QRCodeSVG
            value={qrValue}
            size={190}
            level="H"
            includeMargin={true}
          />
        </div>

        <div className="bg-slate-50 p-3 rounded-2xl border border-slate-100 text-left space-y-1 text-xs">
          <div className="flex justify-between">
            <span className="text-slate-500">No. Invoice:</span>
            <span className="font-bold text-slate-800">{transaction.invoice_no}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-500">Status:</span>
            <span className="font-bold text-emerald-600 uppercase">{transaction.status}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-500">Total Belanja:</span>
            <span className="font-extrabold text-slate-900">Rp {transaction.total.toLocaleString('id-ID')}</span>
          </div>
        </div>

        <div className="mt-5">
          <button
            onClick={() => window.print()}
            className="w-full py-3 bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs rounded-xl transition flex items-center justify-center space-x-2 shadow-md"
          >
            <span>Cetak Bukti Pengambilan</span>
          </button>
        </div>
      </div>
    </div>
  );
}

