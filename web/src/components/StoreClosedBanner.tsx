'use client';

import React, { useEffect, useState } from 'react';
import { fetchStoreStatus } from '@/lib/api';
import { AlertCircle, Clock } from 'lucide-react';

export default function StoreClosedBanner() {
  const [isOpen, setIsOpen] = useState<boolean | null>(null);

  useEffect(() => {
    const checkStatus = async () => {
      const res = await fetchStoreStatus();
      setIsOpen(res.is_open);
    };

    checkStatus();
    const interval = setInterval(checkStatus, 20000); // Poll every 20s

    return () => clearInterval(interval);
  }, []);

  if (isOpen === null || isOpen === true) {
    return null;
  }

  return (
    <div className="bg-amber-600 text-white px-4 py-3 shadow-md sticky top-0 z-50 animate-fade-in">
      <div className="max-w-7xl mx-auto flex items-center justify-between flex-wrap gap-2 text-sm font-medium">
        <div className="flex items-center space-x-2">
          <AlertCircle className="w-5 h-5 flex-shrink-0 animate-pulse text-amber-200" />
          <span>
            <strong>Apotek Sedang Tutup:</strong> Toko fisik saat ini sedang tidak beroperasi. Pencarian produk & pemesanan online dinonaktifkan sementara.
          </span>
        </div>
        <div className="flex items-center space-x-1 text-xs bg-amber-700/60 px-2.5 py-1 rounded-full text-amber-100">
          <Clock className="w-3.5 h-3.5" />
          <span>Buka kembali saat jam kerja kasir</span>
        </div>
      </div>
    </div>
  );
}

