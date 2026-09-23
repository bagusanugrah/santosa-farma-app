'use client';

import React from 'react';
import { Product } from '@/lib/api';
import { useCart } from '@/context/CartContext';
import { Plus, Check, AlertCircle, Pill } from 'lucide-react';

interface ProductCardProps {
  product: Product;
  disabled?: boolean;
}

export default function ProductCard({ product, disabled = false }: ProductCardProps) {
  const { addItem, items } = useCart();
  const cartItem = items.find((i) => i.product.id === product.id);
  const isInCart = Boolean(cartItem);
  const isOutOfStock = product.stock <= 0;

  return (
    <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden hover:shadow-lg transition-all duration-200 flex flex-col group">
      {/* Product Image / Placeholder */}
      <div className="relative w-full h-44 bg-slate-100 flex items-center justify-center overflow-hidden border-b border-slate-100">
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
            <div className="w-12 h-12 rounded-2xl bg-slate-200/80 flex items-center justify-center text-slate-500 mb-2">
              <Pill className="w-6 h-6" />
            </div>
            <span className="text-xs font-medium text-slate-400">Apotek Santosa</span>
          </div>
        )}

        {/* Category Badge */}
        {product.category && (
          <span className="absolute top-2.5 left-2.5 bg-white/90 backdrop-blur-sm text-slate-700 text-[11px] font-semibold px-2.5 py-1 rounded-lg border border-slate-200/60 shadow-sm">
            {product.category}
          </span>
        )}

        {/* Stock Badge */}
        <span
          className={`absolute top-2.5 right-2.5 text-[11px] font-bold px-2 py-0.5 rounded-lg ${
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
      <div className="p-4 flex-1 flex flex-col justify-between">
        <div>
          <h3 className="font-bold text-slate-900 text-sm leading-snug line-clamp-2 min-h-[2.5rem]" title={product.name}>
            {product.name}
          </h3>
          {product.description && (
            <p className="text-xs text-slate-500 line-clamp-2 mt-1 leading-relaxed">
              {product.description}
            </p>
          )}
        </div>

        <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between">
          <div>
            <span className="text-[11px] text-slate-400 font-medium block">Harga</span>
            <span className="font-extrabold text-slate-900 text-base">
              Rp {product.price.toLocaleString('id-ID')}
            </span>
          </div>

          <button
            onClick={() => addItem(product)}
            disabled={disabled || isOutOfStock}
            className={`flex items-center space-x-1 px-3 py-2 rounded-xl text-xs font-bold transition shadow-sm ${
              disabled || isOutOfStock
                ? 'bg-slate-100 text-slate-400 cursor-not-allowed'
                : isInCart
                ? 'bg-brand-50 text-brand-700 border border-brand-200 hover:bg-brand-100'
                : 'bg-brand-600 hover:bg-brand-700 text-white'
            }`}
          >
            {isInCart ? (
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

