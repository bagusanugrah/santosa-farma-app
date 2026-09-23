'use client';

import React from 'react';
import Link from 'next/link';
import { useAuth } from '@/context/AuthContext';
import { useCart } from '@/context/CartContext';
import { ShoppingBag, User, LogOut, Package, Cross } from 'lucide-react';

export default function Header() {
  const { user, logout } = useAuth();
  const { totalItems, setIsOpen } = useCart();

  return (
    <header className="bg-white border-b border-slate-200 sticky top-0 z-40 shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center space-x-3 group">
          <div className="w-10 h-10 rounded-xl bg-brand-600 flex items-center justify-center text-white shadow-md group-hover:bg-brand-700 transition">
            <span className="font-black text-xl">✚</span>
          </div>
          <div>
            <h1 className="font-bold text-slate-900 text-lg leading-tight tracking-tight">
              Apotek Santosa Farma
            </h1>
            <p className="text-xs text-slate-500 font-medium">Jalancagak, Subang</p>
          </div>
        </Link>

        {/* Right Navigation */}
        <div className="flex items-center space-x-3 sm:space-x-4">
          <Link
            href="/"
            className="text-sm font-semibold text-slate-700 hover:text-brand-600 transition px-2 py-1"
          >
            Katalog
          </Link>

          {user && (
            <Link
              href="/orders"
              className="text-sm font-semibold text-slate-700 hover:text-brand-600 transition flex items-center space-x-1.5 px-2 py-1"
            >
              <Package className="w-4 h-4 text-slate-500" />
              <span className="hidden sm:inline">Pesanan Saya</span>
            </Link>
          )}

          {/* Cart Button */}
          <button
            onClick={() => setIsOpen(true)}
            className="relative p-2 text-slate-700 hover:text-brand-600 hover:bg-slate-50 rounded-xl transition"
            aria-label="Keranjang Belanja"
          >
            <ShoppingBag className="w-6 h-6" />
            {totalItems > 0 && (
              <span className="absolute -top-1 -right-1 bg-brand-600 text-white text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center shadow-md animate-scale">
                {totalItems}
              </span>
            )}
          </button>

          {/* User Profile / Auth */}
          {user ? (
            <div className="flex items-center space-x-2 border-l border-slate-200 pl-3">
              <Link
                href="/profile"
                className="flex items-center space-x-2 text-sm font-medium text-slate-800 hover:text-brand-600 transition bg-slate-100 hover:bg-slate-200/80 px-3 py-1.5 rounded-xl"
              >
                <div className="w-6 h-6 rounded-full bg-brand-600 text-white flex items-center justify-center text-xs font-bold">
                  {user.name.charAt(0).toUpperCase()}
                </div>
                <span className="max-w-[100px] truncate hidden md:inline">{user.name}</span>
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
            <div className="flex items-center space-x-2 border-l border-slate-200 pl-3">
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

