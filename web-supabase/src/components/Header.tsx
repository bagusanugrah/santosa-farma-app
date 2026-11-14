'use client';

import React from 'react';
import Link from 'next/link';
import { useAuth } from '@/context/AuthContext';
import { useCart } from '@/context/CartContext';
import { useStoreStatus } from '@/context/StoreStatusContext';
import { ShoppingBag, User, LogOut, Package, Store } from 'lucide-react';

export default function Header() {
  const { user, logout } = useAuth();
  const { totalItems, setIsOpen } = useCart();
  const { onlineOrdersEnabled } = useStoreStatus();

  return (
    <header className="bg-white border-b border-slate-200 sticky top-0 z-40 shadow-xs">
      <div className="max-w-7xl mx-auto px-3.5 sm:px-6 lg:px-8 h-14 sm:h-16 flex items-center justify-between">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center space-x-2.5 sm:space-x-3 group min-w-0">
          <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-xl bg-brand-600 flex items-center justify-center text-white shadow-md group-hover:bg-brand-700 transition flex-shrink-0">
            <span className="font-black text-lg sm:text-xl">✚</span>
          </div>
          <div className="min-w-0">
            <h1 className="font-extrabold text-slate-900 text-sm sm:text-lg leading-tight tracking-tight truncate">
              Apotek Santosa Farma
            </h1>
            <p className="text-[11px] text-slate-500 font-medium hidden sm:block">Jalancagak, Subang</p>
          </div>
        </Link>

        {/* Right Navigation */}
        <div className="flex items-center space-x-2 sm:space-x-4">
          {!onlineOrdersEnabled && (
            <div className="hidden sm:flex items-center space-x-1.5 text-xs font-bold bg-amber-50 text-amber-800 px-2.5 py-1 rounded-xl border border-amber-200">
              <Store className="w-3.5 h-3.5 text-amber-600" />
              <span>Beli Langsung di Apotek</span>
            </div>
          )}

          {/* Desktop-only Nav Links */}
          <Link
            href="/"
            className="hidden md:inline-block text-sm font-semibold text-slate-700 hover:text-brand-600 transition px-2 py-1"
          >
            Katalog
          </Link>

          {user && (
            <Link
              href="/orders"
              className="hidden md:flex text-sm font-semibold text-slate-700 hover:text-brand-600 transition items-center space-x-1.5 px-2 py-1"
            >
              <Package className="w-4 h-4 text-slate-500" />
              <span>Pesanan Saya</span>
            </Link>
          )}

          {/* Cart Button (Always visible on mobile & desktop) */}
          <button
            onClick={() => setIsOpen(true)}
            className="relative p-2 text-slate-700 hover:text-brand-600 hover:bg-slate-50 rounded-xl transition"
            aria-label="Keranjang Belanja"
          >
            <ShoppingBag className="w-5 h-5 sm:w-6 sm:h-6" />
            {totalItems > 0 && (
              <span className="absolute -top-0.5 -right-0.5 sm:-top-1 sm:-right-1 bg-brand-600 text-white text-[10px] sm:text-xs font-bold w-4 h-4 sm:w-5 sm:h-5 rounded-full flex items-center justify-center shadow-md animate-scale">
                {totalItems > 99 ? '99+' : totalItems}
              </span>
            )}
          </button>

          {/* Desktop User Profile / Auth Links (On mobile, accessible via MobileBottomNav) */}
          {user ? (
            <div className="hidden md:flex items-center space-x-2 border-l border-slate-200 pl-3">
              <Link
                href="/profile"
                className="flex items-center space-x-2 text-sm font-medium text-slate-800 hover:text-brand-600 transition bg-slate-100 hover:bg-slate-200/80 px-3 py-1.5 rounded-xl"
              >
                <div className="w-6 h-6 rounded-full bg-brand-600 text-white flex items-center justify-center text-xs font-bold">
                  {user.name.charAt(0).toUpperCase()}
                </div>
                <span className="max-w-[120px] truncate">{user.name}</span>
              </Link>
              <button
                onClick={logout}
                title="Logout"
                className="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-xl transition"
              >
                <LogOut className="w-4 h-4" />
              </button>
            </div>
          ) : (
            <div className="hidden md:flex items-center space-x-2 border-l border-slate-200 pl-3">
              <Link
                href="/login"
                className="text-sm font-medium text-slate-700 hover:text-slate-900 px-3 py-1.5 rounded-xl transition"
              >
                Masuk
              </Link>
              <Link
                href="/register"
                className="text-sm font-semibold bg-brand-600 hover:bg-brand-700 text-white px-4 py-1.5 rounded-xl transition shadow-sm"
              >
                Daftar
              </Link>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

