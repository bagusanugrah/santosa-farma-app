'use client';

import React from 'react';
import { useCart } from '@/context/CartContext';
import { useAuth } from '@/context/AuthContext';
import { useStoreStatus } from '@/context/StoreStatusContext';
import { useRouter } from 'next/navigation';
import { X, Trash2, Plus, Minus, ShoppingBag, ArrowRight, Store } from 'lucide-react';

export default function CartDrawer() {
  const { items, isOpen, setIsOpen, updateQty, removeItem, totalPrice, totalItems } = useCart();
  const { user } = useAuth();
  const router = useRouter();
  const { onlineOrdersEnabled } = useStoreStatus();

  if (!isOpen) return null;

  const handleCheckout = () => {
    if (!onlineOrdersEnabled) return;
    setIsOpen(false);
    if (!user) {
      router.push('/login?redirect=/checkout');
    } else {
      router.push('/checkout');
    }
  };

  return (
    <div className="fixed inset-0 z-50 overflow-hidden">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-slate-900/50 backdrop-blur-sm transition-opacity"
        onClick={() => setIsOpen(false)}
      />

      <div className="fixed inset-y-0 right-0 max-w-full flex sm:pl-10">
        <div className="w-screen max-w-md bg-white shadow-2xl flex flex-col">
          {/* Header */}
          <div className="p-4 sm:p-5 border-b border-slate-200 flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <ShoppingBag className="w-5 h-5 text-brand-600" />
              <h2 className="font-bold text-slate-900 text-base sm:text-lg">Keranjang Belanja</h2>
              <span className="bg-slate-100 text-slate-600 text-xs font-bold px-2 py-0.5 rounded-full">
                {totalItems} item
              </span>
            </div>
            <button
              onClick={() => setIsOpen(false)}
              className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg hover:bg-slate-100 transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* Items List */}
          <div className="flex-1 overflow-y-auto p-4 sm:p-5 space-y-3 sm:space-y-4">
            {items.length === 0 ? (
              <div className="h-full flex flex-col items-center justify-center text-center text-slate-400">
                <div className="w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center mb-3 text-slate-300">
                  <ShoppingBag className="w-8 h-8" />
                </div>
                <p className="font-bold text-slate-600">Keranjang masih kosong</p>
                <p className="text-xs text-slate-400 mt-1">Pilih obat dari katalog untuk menambahkan ke keranjang.</p>
              </div>
            ) : (
              items.map(({ product, qty }) => (
                <div
                  key={product.id}
                  className="flex items-center space-x-3 p-3 bg-slate-50 rounded-2xl border border-slate-100"
                >
                  <div className="w-14 h-14 rounded-xl bg-white border border-slate-200 overflow-hidden flex-shrink-0 flex items-center justify-center">
                    {product.image_url ? (
                      <img
                        src={product.image_url}
                        alt={product.name}
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          e.currentTarget.style.display = 'none';
                          const fallback = e.currentTarget.parentElement?.querySelector('.cart-pill-fallback');
                          if (fallback) fallback.classList.remove('hidden');
                        }}
                      />
                    ) : null}
                    <span className={`text-xl cart-pill-fallback ${product.image_url ? 'hidden' : ''}`}>💊</span>
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="text-xs font-bold text-slate-900 truncate">{product.name}</h4>
                    <p className="text-xs font-extrabold text-brand-700 mt-0.5">
                      Rp {product.price.toLocaleString('id-ID')}
                    </p>
                    <div className="flex items-center space-x-2 mt-2">
                      <button
                        onClick={() => updateQty(product.id, qty - 1)}
                        className="w-6 h-6 rounded-md bg-white border border-slate-300 flex items-center justify-center hover:bg-slate-100 text-slate-700"
                      >
                        <Minus className="w-3 h-3" />
                      </button>
                      <span className="text-xs font-bold text-slate-800 w-5 text-center">{qty}</span>
                      <button
                        onClick={() => updateQty(product.id, qty + 1)}
                        disabled={qty >= product.stock}
                        className="w-6 h-6 rounded-md bg-white border border-slate-300 flex items-center justify-center hover:bg-slate-100 text-slate-700 disabled:opacity-50"
                      >
                        <Plus className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                  <div className="text-right">
                    <span className="text-xs font-bold text-slate-900 block">
                      Rp {(product.price * qty).toLocaleString('id-ID')}
                    </span>
                    <button
                      onClick={() => removeItem(product.id)}
                      className="text-slate-400 hover:text-red-600 mt-2 p-1 transition"
                      title="Hapus"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Footer */}
          {items.length > 0 && (
            <div className="p-5 border-t border-slate-200 bg-slate-50 space-y-4">
              {!onlineOrdersEnabled && (
                <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-amber-900 text-xs flex items-center space-x-2">
                  <Store className="w-4 h-4 text-amber-600 flex-shrink-0" />
                  <span>
                    Fitur pemesanan online sedang dinonaktifkan sementara oleh kasir. Silakan beli langsung di apotek.
                  </span>
                </div>
              )}
              <div className="flex items-center justify-between text-sm">
                <span className="text-slate-500 font-medium">Total Tagihan:</span>
                <span className="text-lg font-black text-slate-900">
                  Rp {totalPrice.toLocaleString('id-ID')}
                </span>
              </div>
              <button
                onClick={handleCheckout}
                disabled={!onlineOrdersEnabled}
                className={`w-full font-bold py-3.5 px-4 rounded-xl flex items-center justify-center space-x-2 transition ${
                  onlineOrdersEnabled
                    ? 'bg-brand-600 hover:bg-brand-700 text-white shadow-lg shadow-brand-600/20'
                    : 'bg-slate-200 text-slate-500 cursor-not-allowed'
                }`}
              >
                <span>{onlineOrdersEnabled ? 'Lanjut ke Pembayaran' : 'Pembelian di Web Dinonaktifkan'}</span>
                {onlineOrdersEnabled && <ArrowRight className="w-4 h-4" />}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

