'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { useCart } from '@/context/CartContext';
import { API_BASE_URL, fetchStoreStatus } from '@/lib/api';
import QrPickupModal from '@/components/QrPickupModal';
import { ShoppingBag, CreditCard, ShieldCheck, CheckCircle2, ArrowRight, AlertCircle, Sparkles } from 'lucide-react';

declare global {
  interface Window {
    snap: any;
  }
}

export default function CheckoutPage() {
  const router = useRouter();
  const { user, token, loading: authLoading } = useAuth();
  const { items, totalPrice, clearCart } = useCart();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [createdTrx, setCreatedTrx] = useState<any>(null);
  const [showQrModal, setShowQrModal] = useState(false);

  // Load Midtrans Snap Script
  useEffect(() => {
    const snapScriptUrl = 'https://app.sandbox.midtrans.com/snap/snap.js';
    const clientKey = process.env.NEXT_PUBLIC_MIDTRANS_CLIENT_KEY || 'SB-Mid-client-demo';

    const script = document.createElement('script');
    script.src = snapScriptUrl;
    script.setAttribute('data-client-key', clientKey);
    script.async = true;
    document.body.appendChild(script);

    return () => {
      document.body.removeChild(script);
    };
  }, []);

  useEffect(() => {
    if (authLoading) return;

    if (!token || !user) {
      router.push('/login?redirect=/checkout');
    }
  }, [user, token, authLoading, router]);

  if (!user) return null;

  if (items.length === 0 && !createdTrx) {
    return (
      <div className="max-w-md mx-auto py-16 text-center">
        <div className="w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center mx-auto mb-4 text-slate-400">
          <ShoppingBag className="w-8 h-8" />
        </div>
        <h3 className="text-xl font-bold text-slate-800">Keranjang Belanja Kosong</h3>
        <p className="text-xs text-slate-500 mt-1 mb-6">Pilih obat dari katalog untuk melakukan pemesanan.</p>
        <button
          onClick={() => router.push('/')}
          className="px-6 py-2.5 bg-brand-600 hover:bg-brand-700 text-white font-bold text-xs rounded-xl shadow-md transition"
        >
          Lihat Katalog
        </button>
      </div>
    );
  }

  const handlePayNow = async () => {
    // Check if store is open
    const storeStatus = await fetchStoreStatus();
    if (!storeStatus.is_open) {
      setError('Mohon maaf, Apotek Santosa Farma saat ini sedang tutup. Pemesanan tidak dapat diproses.');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const payload = {
        items: items.map((i) => ({
          product_id: i.product.id,
          qty: i.qty,
        })),
      };

      const res = await fetch(`${API_BASE_URL}/transactions/checkout`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      });

      const json = await res.json();
      if (!res.ok) {
        throw new Error(json.message || 'Gagal memproses checkout.');
      }

      const transaction = json.data.transaction;
      const snapToken = json.data.snap_token;
      setCreatedTrx(transaction);

      // Trigger Midtrans Snap or Mock Simulator
      if (window.snap && snapToken && !snapToken.startsWith('mock-')) {
        window.snap.pay(snapToken, {
          onSuccess: function (result: any) {
            clearCart();
            router.push('/orders');
          },
          onPending: function (result: any) {
            clearCart();
            router.push('/orders');
          },
          onError: function (result: any) {
            setError('Pembayaran gagal atau dibatalkan.');
          },
          onClose: function () {
            clearCart();
            router.push('/orders');
          },
        });
      } else {
        // Mock Sandbox Payment Simulator
        setTimeout(() => {
          clearCart();
          setShowQrModal(true);
        }, 1000);
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div className="flex items-center space-x-2">
        <CreditCard className="w-6 h-6 text-brand-600" />
        <h2 className="text-2xl font-black text-slate-900">Konfirmasi Pemesanan & Pembayaran</h2>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-2xl flex items-center space-x-2">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Items Summary */}
        <div className="md:col-span-2 space-y-4">
          <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm">
            <h3 className="text-sm font-bold text-slate-900 mb-4 flex items-center justify-between">
              <span>Daftar Obat yang Dipesan</span>
              <span className="text-xs text-slate-500 font-normal">{items.length} jenis obat</span>
            </h3>

            <div className="divide-y divide-slate-100">
              {items.map(({ product, qty }) => (
                <div key={product.id} className="py-3 flex items-center justify-between text-xs">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center flex-shrink-0">
                      {product.image_url ? (
                        <img src={product.image_url} alt={product.name} className="w-full h-full object-cover rounded-xl" />
                      ) : (
                        <span>💊</span>
                      )}
                    </div>
                    <div>
                      <h4 className="font-bold text-slate-900">{product.name}</h4>
                      <p className="text-slate-500 mt-0.5">
                        {qty} x Rp {product.price.toLocaleString('id-ID')}
                      </p>
                    </div>
                  </div>
                  <span className="font-extrabold text-slate-900">
                    Rp {(product.price * qty).toLocaleString('id-ID')}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Pickup Information */}
          <div className="bg-brand-50/60 rounded-3xl border border-brand-200 p-6">
            <div className="flex items-start space-x-3">
              <ShieldCheck className="w-6 h-6 text-brand-600 flex-shrink-0 mt-0.5" />
              <div>
                <h4 className="font-bold text-brand-900 text-sm">Metode Pengambilan di Toko</h4>
                <p className="text-xs text-brand-800/90 mt-1 leading-relaxed">
                  Setelah pembayaran selesai, Anda akan menerima <strong>Kode QR Pengambilan Pesanan</strong>. Tunjukkan kode QR tersebut langsung kepada kasir di Apotek Santosa Farma (Jl. Raya Jalancagak, Subang) saat mengambil obat.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Customer Details & Pay Button */}
        <div className="space-y-4">
          <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm space-y-4">
            <h3 className="text-sm font-bold text-slate-900">Data Pemesan</h3>
            <div className="space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-slate-500">Nama:</span>
                <span className="font-bold text-slate-800">{user.name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">WhatsApp:</span>
                <span className="font-bold text-slate-800">{user.phone || '-'}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Email:</span>
                <span className="font-bold text-slate-800">{user.email || '-'}</span>
              </div>
            </div>

            <div className="pt-4 border-t border-slate-100 space-y-2">
              <div className="flex justify-between text-xs text-slate-500">
                <span>Subtotal</span>
                <span>Rp {totalPrice.toLocaleString('id-ID')}</span>
              </div>
              <div className="flex justify-between text-xs text-slate-500">
                <span>Biaya Layanan</span>
                <span className="text-emerald-600 font-bold">GRATIS</span>
              </div>
              <div className="flex justify-between text-sm font-black text-slate-900 pt-2 border-t border-slate-100">
                <span>Total Bayar</span>
                <span className="text-brand-600 text-base">
                  Rp {totalPrice.toLocaleString('id-ID')}
                </span>
              </div>
            </div>

            <button
              onClick={handlePayNow}
              disabled={loading}
              className="w-full py-3.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold rounded-2xl transition shadow-lg shadow-brand-600/20 text-xs flex items-center justify-center space-x-2"
            >
              <span>{loading ? 'Menyiapkan Pembayaran...' : 'Bayar Sekarang (Midtrans)'}</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      <QrPickupModal
        isOpen={showQrModal}
        onClose={() => {
          setShowQrModal(false);
          router.push('/orders');
        }}
        transaction={createdTrx}
      />
    </div>
  );
}

