'use client';

import React from 'react';
import { useStoreStatus } from '@/context/StoreStatusContext';
import { AlertCircle, Clock, ShoppingBag, Store } from 'lucide-react';

export default function StoreClosedBanner() {
  const { isOpen, onlineOrdersEnabled } = useStoreStatus();

  // Case 1: Store is physically closed
  if (!isOpen) {
    return (
      <div className="bg-rose-700 text-white px-4 py-3 shadow-md sticky top-0 z-50 animate-fade-in">
        <div className="max-w-7xl mx-auto flex items-center justify-between flex-wrap gap-2 text-sm font-medium">
          <div className="flex items-center space-x-2">
            <AlertCircle className="w-5 h-5 flex-shrink-0 animate-pulse text-rose-200" />
            <span>
              <strong>Apotek Sedang Tutup:</strong> Toko fisik saat ini sedang tidak beroperasi.
            </span>
          </div>
          <div className="flex items-center space-x-1 text-xs bg-rose-800/80 px-2.5 py-1 rounded-full text-rose-100">
            <Clock className="w-3.5 h-3.5" />
            <span>Buka kembali saat jam kerja kasir</span>
          </div>
        </div>
      </div>
    );
  }

  // Case 2: Store is open, but cashier disabled online orders
  if (!onlineOrdersEnabled) {
    return (
      <div className="bg-amber-600 text-white px-4 py-2.5 shadow-md sticky top-0 z-50 animate-fade-in border-b border-amber-500">
        <div className="max-w-7xl mx-auto flex items-center justify-between flex-wrap gap-2 text-xs sm:text-sm font-medium">
          <div className="flex items-center space-x-2">
            <Store className="w-4 h-4 flex-shrink-0 text-amber-200" />
            <span>
              <strong>Mode Katalog & Informasi:</strong> Pembelian online sedang dinonaktifkan sementara oleh kasir. Apotek saat ini melayani pembelian langsung di kasir toko.
            </span>
          </div>
          <div className="flex items-center space-x-1 text-xs bg-amber-700/80 px-2.5 py-1 rounded-full text-amber-100 font-semibold">
            <ShoppingBag className="w-3.5 h-3.5" />
            <span>Beli Langsung di Apotek</span>
          </div>
        </div>
      </div>
    );
  }

  return null;
}

