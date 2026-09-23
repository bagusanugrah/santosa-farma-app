'use client';

import React from 'react';
import { Transaction, API_BASE_URL } from '@/lib/api';
import { Printer, Download, X, CheckCircle2 } from 'lucide-react';

interface ReceiptModalProps {
  isOpen: boolean;
  onClose: () => void;
  transaction: Transaction | null;
}

export default function ReceiptModal({ isOpen, onClose, transaction }: ReceiptModalProps) {
  if (!isOpen || !transaction) return null;

  const handlePrint = () => {
    window.print();
  };

  const handleDownloadPdf = () => {
    window.open(`${API_BASE_URL}/receipts/${transaction.id}/pdf`, '_blank');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
      <div className="bg-white rounded-3xl max-w-md w-full p-6 shadow-2xl relative animate-scale flex flex-col max-h-[90vh]">
        {/* Modal Controls */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-100 no-print">
          <div className="flex items-center space-x-2">
            <CheckCircle2 className="w-5 h-5 text-brand-600" />
            <h3 className="font-bold text-slate-900 text-base">Struk Pembayaran Kasir</h3>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg hover:bg-slate-100 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Printable Thermal Receipt Area */}
        <div className="overflow-y-auto flex-1 my-4 p-4 bg-slate-50 border border-slate-200 rounded-2xl font-mono text-xs text-slate-900 printable-receipt">
          <div className="text-center space-y-1 pb-3 border-b border-dashed border-slate-300">
            <h2 className="font-black text-sm uppercase">APOTEK SANTOSA FARMA</h2>
            <p className="text-[10px] text-slate-600">Jl. Raya Jalancagak, Subang, Jawa Barat</p>
            <p className="text-[10px] text-slate-600">Telp: (0260) 123456 / 0812-3456-7890</p>
          </div>

          <div className="py-2.5 border-b border-dashed border-slate-300 space-y-1 text-[11px]">
            <div className="flex justify-between">
              <span>No: {transaction.invoice_no}</span>
              <span>{new Date(transaction.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
            <div className="flex justify-between">
              <span>Kasir: {transaction.cashier?.name || 'Kasir Santosa'}</span>
              <span className="uppercase">Tipe: {transaction.channel}</span>
            </div>
            {transaction.customer && (
              <div>Pelanggan: {transaction.customer.name}</div>
            )}
          </div>

          {/* Items Table */}
          <div className="py-2.5 border-b border-dashed border-slate-300 space-y-2">
            {transaction.items?.map((item, idx) => (
              <div key={idx} className="space-y-0.5">
                <div className="font-bold text-[11px] truncate">{item.product_name}</div>
                <div className="flex justify-between text-[10px] text-slate-600">
                  <span>{item.qty} x Rp {item.price.toLocaleString('id-ID')}</span>
                  <span className="font-bold text-slate-900">Rp {item.subtotal.toLocaleString('id-ID')}</span>
                </div>
              </div>
            ))}
          </div>

          {/* Totals */}
          <div className="py-2.5 border-b border-dashed border-slate-300 space-y-1 text-[11px]">
            <div className="flex justify-between font-black text-xs">
              <span>TOTAL</span>
              <span>Rp {transaction.total.toLocaleString('id-ID')}</span>
            </div>
            <div className="flex justify-between text-slate-600">
              <span>Metode Bayar</span>
              <span className="uppercase font-bold">{transaction.payment_method}</span>
            </div>
            {transaction.amount_paid !== null && (
              <>
                <div className="flex justify-between text-slate-600">
                  <span>Tunai Diterima</span>
                  <span>Rp {transaction.amount_paid.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between text-slate-600 font-bold">
                  <span>Kembalian</span>
                  <span>Rp {(transaction.change_amount || 0).toLocaleString('id-ID')}</span>
                </div>
              </>
            )}
            <div className="flex justify-between text-slate-600 pt-1">
              <span>Status</span>
              <span className="font-bold uppercase text-emerald-600">{transaction.status}</span>
            </div>
          </div>

          <div className="text-center pt-3 text-[10px] text-slate-500 space-y-1">
            <p className="font-bold">Terima Kasih — Semoga Lekas Sembuh</p>
            <p className="text-[9px]">Barang yang dibeli tidak dapat ditukar/dikembalikan.</p>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="pt-2 grid grid-cols-2 gap-3 no-print">
          <button
            onClick={handlePrint}
            className="py-3 bg-brand-600 hover:bg-brand-700 text-white font-bold text-xs rounded-xl shadow-md flex items-center justify-center space-x-2 transition"
          >
            <Printer className="w-4 h-4" />
            <span>Cetak Struk</span>
          </button>
          <button
            onClick={handleDownloadPdf}
            className="py-3 bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs rounded-xl shadow-md flex items-center justify-center space-x-2 transition"
          >
            <Download className="w-4 h-4" />
            <span>Simpan PDF</span>
          </button>
        </div>
      </div>
    </div>
  );
}

