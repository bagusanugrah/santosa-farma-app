'use client';

import React, { useState } from 'react';
import { Transaction, API_BASE_URL } from '@/lib/api';
import { PackageCheck, X, AlertCircle, CheckCircle2, User, Phone, Calendar, Receipt } from 'lucide-react';

interface ConfirmPickupModalProps {
  isOpen: boolean;
  onClose: () => void;
  transaction: Transaction | null;
  onSuccess: (updatedTransaction: Transaction) => void;
  token: string | null;
}

export default function ConfirmPickupModal({
  isOpen,
  onClose,
  transaction,
  onSuccess,
  token,
}: ConfirmPickupModalProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen || !transaction) return null;

  const handleConfirm = async () => {
    if (!token) {
      setError('Sesi kasir tidak valid. Harap login kembali.');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const targetParam = transaction.qr_token || transaction.id;
      const res = await fetch(`${API_BASE_URL}/transactions/pickup/${encodeURIComponent(targetParam)}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
      });

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.message || 'Gagal mengonfirmasi pengambilan obat.');
      }

      onSuccess(data.data);
      onClose();
    } catch (err: any) {
      setError(err.message || 'Terjadi kesalahan sistem saat memproses konfirmasi.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
      <div className="bg-white rounded-3xl max-w-lg w-full p-6 shadow-2xl relative flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-100">
          <div className="flex items-center space-x-2.5">
            <div className="w-10 h-10 rounded-2xl bg-emerald-100 text-emerald-700 flex items-center justify-center">
              <PackageCheck className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-extrabold text-slate-900 text-base">Serahkan Obat ke Pelanggan</h3>
              <p className="text-xs text-slate-500">Konfirmasi langsung tanpa perlu scan QR ponsel kasir</p>
            </div>
          </div>
          <button
            onClick={onClose}
            disabled={loading}
            className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg hover:bg-slate-100 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="overflow-y-auto flex-1 my-4 space-y-4 pr-1">
          {error && (
            <div className="p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl flex items-center space-x-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0 text-red-600" />
              <span>{error}</span>
            </div>
          )}

          {/* Customer & Order Information Card */}
          <div className="bg-slate-50 rounded-2xl p-4 border border-slate-200 text-xs space-y-2.5">
            <div className="flex items-center justify-between border-b border-slate-200/80 pb-2">
              <span className="text-slate-500 font-medium">No. Invoice:</span>
              <span className="font-bold text-slate-900 font-mono">{transaction.invoice_no}</span>
            </div>

            <div className="grid grid-cols-2 gap-2 text-slate-600">
              <div className="flex items-center space-x-1.5">
                <User className="w-3.5 h-3.5 text-slate-400" />
                <span className="font-semibold text-slate-900">
                  {transaction.customer?.name || 'Customer Online'}
                </span>
              </div>
              <div className="flex items-center space-x-1.5">
                <Phone className="w-3.5 h-3.5 text-slate-400" />
                <span>{transaction.customer?.phone || '-'}</span>
              </div>
            </div>

            <div className="flex items-center justify-between text-slate-500 pt-1 border-t border-slate-200/80">
              <div className="flex items-center space-x-1.5">
                <Calendar className="w-3.5 h-3.5 text-slate-400" />
                <span>
                  {new Date(transaction.created_at).toLocaleDateString('id-ID', {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </span>
              </div>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase bg-emerald-100 text-emerald-800">
                Lunas ({transaction.payment_method})
              </span>
            </div>
          </div>

          {/* Medicine Items List */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <h4 className="text-xs font-bold text-slate-800 uppercase tracking-wider flex items-center space-x-1.5">
                <Receipt className="w-3.5 h-3.5 text-brand-600" />
                <span>Daftar Obat yang Harus Diserahkan:</span>
              </h4>
              <span className="text-[11px] font-semibold text-slate-500">
                {transaction.items?.length || 0} Item
              </span>
            </div>

            <div className="bg-white border border-slate-200 rounded-2xl divide-y divide-slate-100 overflow-hidden shadow-sm">
              {transaction.items && transaction.items.length > 0 ? (
                transaction.items.map((item, idx) => (
                  <div key={idx} className="p-3 flex items-center justify-between hover:bg-slate-50/60 transition">
                    <div className="space-y-0.5">
                      <p className="font-bold text-xs text-slate-900">{item.product_name}</p>
                      <p className="text-[11px] text-slate-500">
                        {item.qty}x @ Rp {item.price.toLocaleString('id-ID')}
                      </p>
                    </div>
                    <div className="text-right">
                      <span className="font-extrabold text-xs text-slate-900">
                        Rp {item.subtotal.toLocaleString('id-ID')}
                      </span>
                    </div>
                  </div>
                ))
              ) : (
                <div className="p-4 text-center text-xs text-slate-400">
                  Data detail obat tidak tersedia
                </div>
              )}

              {/* Total Row */}
              <div className="p-3 bg-slate-50 flex items-center justify-between font-extrabold text-xs text-slate-900">
                <span>TOTAL PEMBAYARAN</span>
                <span className="text-brand-700 text-sm">
                  Rp {transaction.total.toLocaleString('id-ID')}
                </span>
              </div>
            </div>
          </div>

          {/* Verification Warning Note */}
          <div className="p-3 bg-amber-50 border border-amber-200 text-amber-800 text-[11px] rounded-xl flex items-start space-x-2">
            <CheckCircle2 className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
            <p className="leading-relaxed">
              Mohon periksa fisik obat dan sesuaikan dengan daftar di atas sebelum menyerahkan ke pelanggan. Setelah dikonfirmasi, status pesanan pelanggan di web akan otomatis berubah menjadi <strong>"Sudah Diambil"</strong>.
            </p>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="pt-3 border-t border-slate-100 grid grid-cols-2 gap-3">
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="py-2.5 px-4 bg-slate-100 hover:bg-slate-200 disabled:opacity-50 text-slate-700 font-bold text-xs rounded-xl transition"
          >
            Batal
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            disabled={loading}
            className="py-2.5 px-4 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-md flex items-center justify-center space-x-2 transition"
          >
            {loading ? (
              <>
                <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                <span>Memproses...</span>
              </>
            ) : (
              <>
                <PackageCheck className="w-4 h-4" />
                <span>Konfirmasi Diserahkan</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
