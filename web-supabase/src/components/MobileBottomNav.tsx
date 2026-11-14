'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { useCart } from '@/context/CartContext';
import { Store, Package, ShoppingBag, User, LogIn } from 'lucide-react';

export default function MobileBottomNav() {
  const pathname = usePathname();
  const { user } = useAuth();
  const { totalItems, setIsOpen } = useCart();

  const isHomeActive = pathname === '/';
  const isOrdersActive = pathname.startsWith('/orders');
  const isProfileActive = pathname === '/profile' || pathname === '/login' || pathname === '/register';

  return (
    <nav
      aria-label="Navigasi Bawah Mobile"
      className="fixed bottom-0 inset-x-0 z-40 bg-white/95 backdrop-blur-md border-t border-slate-200/80 shadow-[0_-4px_16px_rgba(0,0,0,0.06)] md:hidden transition-all"
    >
      <div className="grid grid-cols-4 h-16 items-center px-1 safe-area-bottom">
        {/* 1. Katalog / Home */}
        <Link
          href="/"
          className={`flex flex-col items-center justify-center py-1 transition-all ${
            isHomeActive
              ? 'text-brand-600 font-bold'
              : 'text-slate-500 hover:text-slate-700 font-medium'
          }`}
        >
          <div className="relative">
            <Store className={`w-5 h-5 transition-transform ${isHomeActive ? 'scale-110' : ''}`} />
          </div>
          <span className="text-[11px] mt-1 leading-none">Katalog</span>
        </Link>

        {/* 2. Pesanan Saya */}
        <Link
          href={user ? '/orders' : '/login?redirect=/orders'}
          className={`flex flex-col items-center justify-center py-1 transition-all ${
            isOrdersActive
              ? 'text-brand-600 font-bold'
              : 'text-slate-500 hover:text-slate-700 font-medium'
          }`}
        >
          <div className="relative">
            <Package className={`w-5 h-5 transition-transform ${isOrdersActive ? 'scale-110' : ''}`} />
          </div>
          <span className="text-[11px] mt-1 leading-none">Pesanan</span>
        </Link>

        {/* 3. Keranjang (Drawer Trigger) */}
        <button
          onClick={() => setIsOpen(true)}
          className="flex flex-col items-center justify-center py-1 text-slate-500 hover:text-brand-600 transition-all font-medium"
        >
          <div className="relative">
            <ShoppingBag className="w-5 h-5" />
            {totalItems > 0 && (
              <span className="absolute -top-1.5 -right-2.5 bg-brand-600 text-white text-[10px] font-black w-4 h-4 rounded-full flex items-center justify-center shadow-sm animate-scale">
                {totalItems > 99 ? '99+' : totalItems}
              </span>
            )}
          </div>
          <span className="text-[11px] mt-1 leading-none">Keranjang</span>
        </button>

        {/* 4. Profil / Akun */}
        <Link
          href={user ? '/profile' : '/login'}
          className={`flex flex-col items-center justify-center py-1 transition-all ${
            isProfileActive
              ? 'text-brand-600 font-bold'
              : 'text-slate-500 hover:text-slate-700 font-medium'
          }`}
        >
          <div className="relative">
            {user ? (
              <div
                className={`w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-black transition-all ${
                  isProfileActive
                    ? 'bg-brand-600 text-white shadow-xs'
                    : 'bg-slate-200 text-slate-700'
                }`}
              >
                {user.name.charAt(0).toUpperCase()}
              </div>
            ) : (
              <User className={`w-5 h-5 transition-transform ${isProfileActive ? 'scale-110' : ''}`} />
            )}
          </div>
          <span className="text-[11px] mt-1 leading-none">
            {user ? 'Akun' : 'Masuk'}
          </span>
        </Link>
      </div>
    </nav>
  );
}
