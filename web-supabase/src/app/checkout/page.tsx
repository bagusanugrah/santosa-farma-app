'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { useCart } from '@/context/CartContext';
import { useStoreStatus } from '@/context/StoreStatusContext';
import { API_BASE_URL, fetchStoreStatus, getProductImageUrl } from '@/lib/api';
import QrPickupModal from '@/components/QrPickupModal';
import { ShoppingBag, CreditCard, ShieldCheck, CheckCircle2, ArrowRight, AlertCircle, Sparkles, Store } from 'lucide-react';

declare global {
  interface Window {
    snap: any;
  }
}

export default function CheckoutPage() {
  const router = useRouter();
  const { user, token, loading: authLoading } = useAuth();
  const { items, totalPrice, clearCart } = useCart();
  const {
    isOpen,
    onlineOrdersEnabled,
    hasMidtrans,
    loading: statusLoading,
    midtransClientKey,
    midtransIsProduction,
  } = useStoreStatus();

  const [paymentMethod, setPaymentMethod] = useState<'pharmacy' | 'midtrans'>('pharmacy');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [createdTrx, setCreatedTrx] = useState<any>(null);
  const [showQrModal, setShowQrModal] = useState(false);
  const onlineOrdersDisabled = !statusLoading && (!isOpen || !onlineOrdersEnabled);

  // Dynamically load Midtrans Snap Script (Sandbox or Production from Supabase store_settings)
  useEffect(() => {
    if (statusLoading) return;
    const snapScriptUrl = midtransIsProduction
      ? 'https://app.midtrans.com/snap/snap.js'
      : 'https://app.sandbox.midtrans.com/snap/snap.js';
    const clientKey =
      midtransClientKey || process.env.NEXT_PUBLIC_MIDTRANS_CLIENT_KEY || '';

    const scriptId = 'midtrans-snap-script';
    const existing = document.getElementById(scriptId);
    if (existing) {
      existing.remove();
    }

    const script = document.createElement('script');
    script.id = scriptId;
    script.src = snapScriptUrl;
    if (clientKey) {
      script.setAttribute('data-client-key', clientKey);
    }
    script.async = true;
    document.body.appendChild(script);

    return () => {
      if (script.parentNode) {
        script.parentNode.removeChild(script);
      }
    };
  }, [statusLoading, midtransClientKey, midtransIsProduction]);

  useEffect(() => {
    if (authLoading) return;

    if (!token || !user) {
      router.push('/login?redirect=/checkout');
    }
  }, [user, token, authLoading, router]);

  if (authLoading || statusLoading) {
    return (
      <div className="max-w-md mx-auto py-16 flex flex-col items-center justify-center space-y-3">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xs text-slate-500 font-medium">Menyiapkan halaman pembayaran...</p>
      </div>
    );
  }

  if (!user) return null;

  if (onlineOrdersDisabled) {
    return (
      <div className="max-w-md mx-auto py-16 text-center animate-fade-in">
        <div className="w-16 h-16 rounded-2xl bg-amber-100 flex items-center justify-center mx-auto mb-4 text-amber-600 shadow-inner">
          <Store className="w-8 h-8" />
        </div>
        <h3 className="text-xl font-bold text-slate-800">Pemesanan Online Dinonaktifkan</h3>
        <p className="text-xs text-slate-600 mt-2 mb-6 max-w-sm mx-auto leading-relaxed">
          Kasir Apotek Santosa Farma sedang menonaktifkan transaksi online agar dapat fokus melayani antrean langsung di apotek. Silakan beli langsung di kasir toko.
        </p>
        <button
          onClick={() => router.push('/')}
          className="px-6 py-2.5 bg-brand-600 hover:bg-brand-700 text-white font-bold text-xs rounded-xl shadow-md transition"
        >
          Lihat Katalog Obat
        </button>
      </div>
    );
  }

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
    // Check if store is open & online orders enabled
    const storeStatus = await fetchStoreStatus();
    if (!storeStatus.is_open) {
      setError('Mohon maaf, Apotek Santosa Farma saat ini sedang tutup. Pemesanan tidak dapat diproses.');
      return;
    }
    if (!storeStatus.online_orders_enabled) {
      setError('Mohon maaf, fitur pemesanan obat online sedang dinonaktifkan oleh kasir. Pembelian hanya dilayani langsung di apotek.');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const selectedMethod = hasMidtrans ? paymentMethod : 'pharmacy';
      const payload = {
        items: items.map((i) => ({
          product_id: i.product.id,
          qty: i.qty,
        })),
        payment_method: selectedMethod,
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

      // If customer chose Bayar di Apotek, immediately show the QR code modal
      if (selectedMethod === 'pharmacy' || !snapToken) {
        clearCart();
        setShowQrModal(true);
        return;
      }

      // Trigger Midtrans Snap or Mock Simulator
      if (window.snap && snapToken && !snapToken.startsWith('mock-')) {
        window.snap.pay(snapToken, {
          onSuccess: async function () {
            try {
              await fetch(`${API_BASE_URL}/transactions/verify-payment`, {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  Accept: 'application/json',
                  Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify({ invoice_no: transaction.invoice_no }),
              });
            } catch (e) {
              console.error('Verify payment sync error:', e);
            }
            clearCart();
            router.push('/orders');
          },
          onPending: function () {
            clearCart();
            router.push('/orders');
          },
          onError: function () {
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
    <div className="max-w-4xl mx-auto space-y-4 sm:space-y-6">
      <div className="flex items-center space-x-2">
        <CreditCard className="w-5 h-5 sm:w-6 sm:h-6 text-brand-600" />
        <h2 className="text-xl sm:text-2xl font-black text-slate-900">Konfirmasi Pemesanan & Pembayaran</h2>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-2xl flex items-center space-x-2">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 sm:gap-6">
        {/* Items Summary */}
        <div className="md:col-span-2 space-y-4">
          <div className="bg-white rounded-2xl sm:rounded-3xl border border-slate-200 p-4 sm:p-6 shadow-sm">
            <h3 className="text-sm font-bold text-slate-900 mb-4 flex items-center justify-between">
              <span>Daftar Obat yang Dipesan</span>
              <span className="text-xs text-slate-500 font-normal">{items.length} jenis obat</span>
            </h3>

            <div className="divide-y divide-slate-100">
              {items.map(({ product, qty }) => (
                <div key={product.id} className="py-3 flex items-center justify-between text-xs gap-3">
                  <div className="flex items-center space-x-3 min-w-0">
                    <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center flex-shrink-0 overflow-hidden">
                      {product.image_url ? (
                        <img
                          src={getProductImageUrl(product.image_url) || ''}
                          alt={product.name}
                          className="w-full h-full object-cover rounded-xl"
                          onError={(e) => {
                            e.currentTarget.style.display = 'none';
                            const fallback = e.currentTarget.parentElement?.querySelector('.chk-pill-fallback');
                            if (fallback) fallback.classList.remove('hidden');
                          }}
                        />
                      ) : null}
                      <span className={`chk-pill-fallback ${product.image_url ? 'hidden' : ''}`}>💊</span>
                    </div>
                    <div className="min-w-0">
                      <h4 className="font-bold text-slate-900 truncate">{product.name}</h4>
                      <p className="text-slate-500 mt-0.5">
                        {qty} x Rp {product.price.toLocaleString('id-ID')}
                      </p>
                    </div>
                  </div>
                  <span className="font-extrabold text-slate-900 flex-shrink-0">
                    Rp {(product.price * qty).toLocaleString('id-ID')}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Payment Method Selector */}
          <div className="bg-white rounded-2xl sm:rounded-3xl border border-slate-200 p-4 sm:p-6 shadow-sm space-y-3">
            <h3 className="text-sm font-bold text-slate-900 flex items-center justify-between">
              <span>Pilih Metode Pembayaran</span>
              <span className="text-[11px] text-brand-600 font-semibold bg-brand-50 px-2.5 py-0.5 rounded-full border border-brand-100">
                Fleksibel & Aman
              </span>
            </h3>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
              {/* Option 1: Bayar di Apotek */}
              <div
                onClick={() => setPaymentMethod('pharmacy')}
                className={`cursor-pointer rounded-2xl p-4 border-2 transition relative flex flex-col justify-between ${
                  paymentMethod === 'pharmacy'
                    ? 'border-brand-600 bg-brand-50/40 shadow-xs ring-2 ring-brand-600/10'
                    : 'border-slate-200 hover:border-slate-300 bg-white'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <div className="w-9 h-9 rounded-xl bg-brand-100 text-brand-700 flex items-center justify-center">
                      <Store className="w-5 h-5" />
                    </div>
                    <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800">
                      Rekomendasi
                    </span>
                  </div>
                  <h4 className="font-bold text-slate-900 text-xs sm:text-sm">Bayar di Apotek (Kasir)</h4>
                  <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                    Pesan obat lewat web, bayar langsung di kasir (Tunai / QRIS). Pesanan dapat dicek atau disesuaikan dengan kasir jika ada perubahan.
                  </p>
                </div>
                <div className="mt-3 flex items-center space-x-1.5 text-[11px] font-bold text-brand-700">
                  <div className={`w-3.5 h-3.5 rounded-full border flex items-center justify-center ${paymentMethod === 'pharmacy' ? 'border-brand-600 bg-brand-600' : 'border-slate-300'}`}>
                    {paymentMethod === 'pharmacy' && <div className="w-1.5 h-1.5 bg-white rounded-full" />}
                  </div>
                  <span>{paymentMethod === 'pharmacy' ? 'Metode Terpilih' : 'Pilih Metode Ini'}</span>
                </div>
              </div>

              {/* Option 2: Bayar Online via Midtrans */}
              <div
                onClick={() => {
                  if (hasMidtrans) setPaymentMethod('midtrans');
                }}
                className={`rounded-2xl p-4 border-2 transition relative flex flex-col justify-between ${
                  !hasMidtrans
                    ? 'opacity-60 bg-slate-50 border-slate-200 cursor-not-allowed'
                    : paymentMethod === 'midtrans'
                    ? 'border-brand-600 bg-brand-50/40 shadow-xs ring-2 ring-brand-600/10 cursor-pointer'
                    : 'border-slate-200 hover:border-slate-300 bg-white cursor-pointer'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <div className="w-9 h-9 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center">
                      <CreditCard className="w-5 h-5" />
                    </div>
                    {!hasMidtrans && (
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-200 text-slate-600">
                        Belum Aktif
                      </span>
                    )}
                  </div>
                  <h4 className="font-bold text-slate-900 text-xs sm:text-sm">Bayar Online Sekarang</h4>
                  <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                    {hasMidtrans
                      ? 'Bayar langsung dari HP via Midtrans Snap (QRIS, GoPay, ShopeePay, Virtual Account).'
                      : 'Gateway Midtrans belum dikonfigurasi oleh apotek. Gunakan opsi Bayar di Apotek.'}
                  </p>
                </div>
                <div className="mt-3 flex items-center space-x-1.5 text-[11px] font-bold text-slate-600">
                  {hasMidtrans ? (
                    <>
                      <div className={`w-3.5 h-3.5 rounded-full border flex items-center justify-center ${paymentMethod === 'midtrans' ? 'border-brand-600 bg-brand-600' : 'border-slate-300'}`}>
                        {paymentMethod === 'midtrans' && <div className="w-1.5 h-1.5 bg-white rounded-full" />}
                      </div>
                      <span className={paymentMethod === 'midtrans' ? 'text-brand-700' : 'text-slate-600'}>
                        {paymentMethod === 'midtrans' ? 'Metode Terpilih' : 'Pilih Metode Ini'}
                      </span>
                    </>
                  ) : (
                    <span className="text-slate-400 text-[10px]">Hanya opsi Bayar di Kasir yang tersedia</span>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Pickup Information */}
          <div className="bg-brand-50/60 rounded-2xl sm:rounded-3xl border border-brand-200 p-4 sm:p-6">
            <div className="flex items-start space-x-3">
              <ShieldCheck className="w-6 h-6 text-brand-600 flex-shrink-0 mt-0.5" />
              <div>
                <h4 className="font-bold text-brand-900 text-sm">Metode Pengambilan di Toko</h4>
                <p className="text-xs text-brand-800/90 mt-1 leading-relaxed">
                  Setelah pesanan dibuat, Anda akan menerima <strong>Kode QR Pesanan</strong>. Tunjukkan kode QR tersebut langsung kepada kasir di Apotek Santosa Farma (Jl. Raya Jalancagak, Subang) saat mengambil obat.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Customer Details & Pay Button */}
        <div className="space-y-4">
          <div className="bg-white rounded-2xl sm:rounded-3xl border border-slate-200 p-4 sm:p-6 shadow-sm space-y-4">
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
                <span>Total Estimasi</span>
                <span className="text-brand-600 text-base">
                  Rp {totalPrice.toLocaleString('id-ID')}
                </span>
              </div>
            </div>

            {!onlineOrdersEnabled && (
              <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs text-amber-800 flex items-start space-x-2">
                <AlertCircle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                <span>
                  Layanan pemesanan obat online sedang dinonaktifkan sementara oleh kasir apotek.
                </span>
              </div>
            )}

            <button
              onClick={handlePayNow}
              disabled={loading || !onlineOrdersEnabled || !isOpen}
              className="w-full py-3.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold rounded-xl sm:rounded-2xl transition shadow-lg shadow-brand-600/20 text-xs sm:text-sm flex items-center justify-center space-x-2"
            >
              <span>
                {loading
                  ? 'Menyiapkan Pesanan...'
                  : !isOpen
                  ? 'Apotek Sedang Tutup'
                  : !onlineOrdersEnabled
                  ? 'Pemesanan Online Nonaktif'
                  : paymentMethod === 'pharmacy' || !hasMidtrans
                  ? 'Pesan Sekarang (Bayar di Apotek)'
                  : 'Bayar Sekarang (Midtrans Online)'}
              </span>
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

