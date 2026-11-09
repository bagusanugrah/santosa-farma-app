'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useStaffAuth } from '@/context/StaffAuthContext';
import { useStoreStatus } from '@/context/StoreStatusContext';
import {
  LayoutDashboard,
  ShoppingCart,
  History,
  Pill,
  FileSpreadsheet,
  Receipt,
  LogOut,
  Globe,
  ToggleLeft,
  ToggleRight,
  RefreshCw,
} from 'lucide-react';

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout } = useStaffAuth();
  const { onlineOrdersEnabled, toggling, toggleOnlineOrders } = useStoreStatus();

  if (!user || pathname === '/login') return null;

  const isSuperAdmin = user.role === 'super_admin';

  const cashierNav = [
    { label: 'Kasir / POS', href: '/pos', icon: ShoppingCart },
    { label: 'Riwayat Transaksi', href: '/pos-history', icon: History },
  ];

  const adminNav = [
    { label: 'Dashboard Analitik', href: '/admin/dashboard', icon: LayoutDashboard },
    { label: 'Manajemen Produk', href: '/admin/products', icon: Pill },
    { label: 'Semua Transaksi', href: '/admin/transactions', icon: Receipt },
    { label: 'Export & Laporan', href: '/admin/export', icon: FileSpreadsheet },
    { label: 'Kasir / POS', href: '/pos', icon: ShoppingCart },
  ];

  const currentNav = isSuperAdmin ? adminNav : cashierNav;

  const handleLogout = () => {
    logout();
    router.push('/login');
  };

  return (
    <aside className="w-64 bg-slate-900 text-white flex flex-col justify-between p-4 border-r border-slate-800 flex-shrink-0 h-screen sticky top-0">
      <div className="space-y-6">
        {/* Brand */}
        <div className="flex items-center space-x-3 px-3 py-2">
          <div className="w-9 h-9 rounded-xl bg-brand-500 text-slate-900 flex items-center justify-center font-black text-xl shadow-md">
            ✚
          </div>
          <div>
            <h2 className="font-extrabold text-sm text-white tracking-tight leading-tight">
              Santosa Farma
            </h2>
            <p className="text-[11px] text-brand-400 font-semibold">
              {isSuperAdmin ? 'Super Admin Portal' : 'Sistem Kasir Toko'}
            </p>
          </div>
        </div>

        {/* Navigation Items */}
        <nav className="space-y-1">
          {currentNav.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center space-x-3 px-3.5 py-2.5 rounded-xl text-xs font-bold transition ${
                  isActive
                    ? 'bg-brand-600 text-white shadow-md shadow-brand-600/30'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                }`}
              >
                <Icon className="w-4 h-4 flex-shrink-0" />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>
      </div>

      {/* User Info & Logout */}
      <div className="pt-4 border-t border-slate-800 space-y-3">
        {/* Quick Web Orders Trigger Widget */}
        <div
          className={`p-3 rounded-2xl border transition-all ${
            onlineOrdersEnabled
              ? 'bg-emerald-950/40 border-emerald-800/60 text-emerald-300'
              : 'bg-amber-950/40 border-amber-800/60 text-amber-300'
          }`}
        >
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center space-x-1.5 text-xs font-bold">
              <Globe className="w-3.5 h-3.5" />
              <span>Beli Obat di Web</span>
            </div>
            <span
              className={`text-[9px] font-black uppercase px-1.5 py-0.5 rounded tracking-wider ${
                onlineOrdersEnabled
                  ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                  : 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
              }`}
            >
              {onlineOrdersEnabled ? 'Aktif' : 'Mati'}
            </span>
          </div>
          <p className="text-[10px] text-slate-400 leading-tight mb-2">
            {onlineOrdersEnabled ? 'Menerima order online' : 'Katalog etalase saja'}
          </p>
          <button
            onClick={toggleOnlineOrders}
            disabled={toggling}
            className={`w-full py-1.5 px-2 rounded-xl text-[11px] font-bold transition flex items-center justify-center space-x-1 shadow-xs ${
              onlineOrdersEnabled
                ? 'bg-rose-500/20 hover:bg-rose-500/30 text-rose-300 border border-rose-500/30'
                : 'bg-emerald-600 hover:bg-emerald-500 text-white'
            } disabled:opacity-50`}
          >
            {toggling ? (
              <RefreshCw className="w-3 h-3 animate-spin" />
            ) : onlineOrdersEnabled ? (
              <ToggleRight className="w-3.5 h-3.5" />
            ) : (
              <ToggleLeft className="w-3.5 h-3.5" />
            )}
            <span>{onlineOrdersEnabled ? 'Matikan Beli di Web' : 'Aktifkan Beli di Web'}</span>
          </button>
        </div>

        <div className="flex items-center space-x-3 px-3 py-2 bg-slate-800/60 rounded-2xl">
          <div className="w-8 h-8 rounded-xl bg-brand-500/20 text-brand-400 flex items-center justify-center font-bold text-xs">
            {user.name.charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-xs font-bold text-white truncate">{user.name}</p>
            <p className="text-[10px] text-slate-400 font-mono">@{user.username}</p>
          </div>
        </div>

        <button
          onClick={handleLogout}
          className="w-full flex items-center justify-center space-x-2 py-2 px-3 bg-red-500/10 hover:bg-red-500/20 text-red-400 hover:text-red-300 rounded-xl text-xs font-bold transition"
        >
          <LogOut className="w-3.5 h-3.5" />
          <span>Keluar (Logout)</span>
        </button>
      </div>
    </aside>
  );
}

