'use client';

import React from 'react';
import { Product } from '@/lib/api';
import { useCart } from '@/context/CartContext';
import { Plus, Check, AlertCircle, Pill } from 'lucide-react';

interface ProductCardProps {
  product: Product;
  disabled?: boolean;
  onlineOrdersEnabled?: boolean;
}

export default function ProductCard({
  product,
  disabled = false,
  onlineOrdersEnabled = true,
}: ProductCardProps) {
  const { addItem, items } = useCart();
  const cartItem = items.find((i) => i.product.id === product.id);
  const isInCart = Boolean(cartItem);
  const isOutOfStock = product.stock <= 0;
  const isBuyingDisabled = disabled || isOutOfStock || !onlineOrdersEnabled;

  return (
    <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden hover:shadow-lg transition-all duration-200 flex flex-col group">
      {/* Product Image / Placeholder */}
      <div className="relative w-full h-36 sm:h-44 bg-slate-100 flex items-center justify-center overflow-hidden border-b border-slate-100">
        {product.image_url ? (
          <img
            src={product.image_url}
            alt={product.name}
            className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
            onError={(e) => {
              // Fallback to placeholder if image fails to load
              (e.target as HTMLElement).style.display = 'none';
            }}
          />
        ) : (
          <div className="flex flex-col items-center justify-center text-slate-400 p-4 text-center">
            <div className="w-10 h-10 sm:w-12 sm:h-12 rounded-2xl bg-slate-200/80 flex items-center justify-center text-slate-500 mb-2">
              <Pill className="w-5 h-5 sm:w-6 sm:h-6" />
            </div>
            <span className="text-[11px] sm:text-xs font-medium text-slate-400">Apotek Santosa</span>
          </div>
        )}

        {/* Category Badge */}
        {product.category && (
          <span className="absolute top-2 left-2 sm:top-2.5 sm:left-2.5 bg-white/95 backdrop-blur-sm text-slate-700 text-[10px] sm:text-[11px] font-semibold px-2 py-0.5 sm:px-2.5 sm:py-1 rounded-md sm:rounded-lg border border-slate-200/60 shadow-xs truncate max-w-[100px] sm:max-w-none">
            {product.category}
          </span>
        )}

        {/* Stock Badge */}
        <span
          className={`absolute top-2 right-2 sm:top-2.5 sm:right-2.5 text-[10px] sm:text-[11px] font-bold px-1.5 py-0.5 sm:px-2 rounded-md sm:rounded-lg ${
            isOutOfStock
              ? 'bg-rose-100 text-rose-700 border border-rose-200'
              : product.stock < 10
              ? 'bg-amber-100 text-amber-800 border border-amber-200'
              : 'bg-emerald-100 text-emerald-800 border border-emerald-200'
          }`}
        >
          {isOutOfStock ? 'Habis' : `Stok: ${product.stock}`}
        </span>
      </div>

      {/* Product Details */}
      <div className="p-3 sm:p-4 flex-1 flex flex-col justify-between">
        <div>
          <h3 className="font-bold text-slate-900 text-xs sm:text-sm leading-snug line-clamp-2 min-h-[2rem] sm:min-h-[2.5rem]" title={product.name}>
            {product.name}
          </h3>
          {product.description && (
            <p className="text-[11px] sm:text-xs text-slate-500 line-clamp-2 mt-1 leading-relaxed hidden sm:block">
              {product.description}
            </p>
          )}
        </div>

        <div className="mt-3 pt-2.5 border-t border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <div>
            <span className="text-[10px] sm:text-[11px] text-slate-400 font-medium block">Harga</span>
            <span className="font-extrabold text-slate-900 text-sm sm:text-base whitespace-nowrap">
              Rp {product.price.toLocaleString('id-ID')}
            </span>
          </div>

          <button
            onClick={() => !isBuyingDisabled && addItem(product)}
            disabled={isBuyingDisabled}
            title={
              !onlineOrdersEnabled
                ? 'Pembelian online dinonaktifkan oleh kasir. Silakan beli langsung di apotek.'
                : isOutOfStock
                ? 'Stok obat habis'
                : 'Tambah ke Keranjang Belanja'
            }
            className={`w-full sm:w-auto flex items-center justify-center space-x-1 px-3 py-2 rounded-xl text-xs font-bold transition shadow-xs ${
              !onlineOrdersEnabled
                ? 'bg-slate-100 text-slate-500 border border-slate-200 cursor-not-allowed'
                : disabled || isOutOfStock
                ? 'bg-slate-100 text-slate-400 cursor-not-allowed'
                : isInCart
                ? 'bg-brand-50 text-brand-700 border border-brand-200 hover:bg-brand-100'
                : 'bg-brand-600 hover:bg-brand-700 text-white'
            }`}
          >
            {!onlineOrdersEnabled ? (
              <span className="text-[11px] sm:text-xs">Hanya di Kasir</span>
            ) : isInCart ? (
              <>
                <Check className="w-3.5 h-3.5" />
                <span>+({cartItem?.qty})</span>
              </>
            ) : (
              <>
                <Plus className="w-3.5 h-3.5" />
                <span>Beli</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

