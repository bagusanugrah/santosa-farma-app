'use client';

import React from 'react';
import { useStoreStatus } from '@/context/StoreStatusContext';

export default function Footer() {
  const { storeAddress, storePhone } = useStoreStatus();

  const contactParts: string[] = [];
  if (storeAddress) contactParts.push(storeAddress);
  if (storePhone) contactParts.push(`Telp/WA: ${storePhone}`);

  return (
    <footer className="bg-white border-t border-slate-200 mt-auto py-8 mb-16 md:mb-0">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center text-xs text-slate-500 space-y-2">
        <p className="font-bold text-slate-700">Apotek Santosa Farma</p>
        {contactParts.length > 0 && <p>{contactParts.join(' — ')}</p>}
        <p className="text-slate-400">
          © {new Date().getFullYear()} Apotek Santosa Farma. Seluruh Hak Cipta Dilindungi.
        </p>
      </div>
    </footer>
  );
}
