'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useStaffAuth } from '@/context/StaffAuthContext';
import { API_BASE_URL } from '@/lib/api';
import { LogIn, User, Lock, AlertCircle, ShieldCheck, Sparkles } from 'lucide-react';

export default function StaffLoginPage() {
  const router = useRouter();
  const { user, login, loading: authLoading } = useStaffAuth();

  const [username, setUsername] = useState('admin');
  const [password, setPassword] = useState('password123');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (authLoading) return;
    if (user) {
      if (user.role === 'super_admin') {
        router.replace('/admin/dashboard');
      } else {
        router.replace('/pos');
      }
    }
  }, [user, authLoading, router]);

  if (authLoading || user) {
    return (
      <div className="min-h-full flex-1 flex items-center justify-center p-6 bg-slate-950 text-slate-100">
        <div className="w-8 h-8 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const res = await fetch(`${API_BASE_URL}/auth/staff/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          username: username.trim(),
          password,
        }),
      });

      const json = await res.json();
      if (!res.ok) {
        throw new Error(json.message || 'Login gagal.');
      }

      login(json.data.token, json.data.user);

      if (json.data.user.role === 'super_admin') {
        router.push('/admin/dashboard');
      } else {
        router.push('/pos');
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleQuickFill = (role: 'admin' | 'kasir') => {
    setUsername(role);
    setPassword('password123');
    setError('');
  };

  return (
    <div className="min-h-full flex-1 flex items-center justify-center p-6 bg-gradient-to-br from-slate-950 via-slate-900 to-emerald-950 text-slate-100">
      <div className="bg-slate-900/90 border border-slate-800/90 rounded-3xl p-8 max-w-md w-full shadow-2xl shadow-emerald-950/40 backdrop-blur-xl space-y-6">
        {/* Brand Header */}
        <div className="text-center space-y-2.5">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-emerald-600 to-emerald-400 text-slate-950 flex items-center justify-center font-black text-3xl mx-auto shadow-xl shadow-emerald-500/20">
            ✚
          </div>
          <div>
            <h2 className="text-2xl font-black text-white tracking-tight">
              Apotek Santosa Farma
            </h2>
            <p className="text-xs text-slate-400 mt-1">
              Sistem POS Kasir & Portal Manajemen Super Admin
            </p>
          </div>
        </div>

        {error && (
          <div className="p-3.5 bg-red-500/10 border border-red-500/30 text-red-400 text-xs font-semibold rounded-2xl flex items-center space-x-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-xs font-bold text-slate-300 mb-1.5">
              Username Staff
            </label>
            <div className="relative">
              <User className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                required
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="admin atau kasir"
                className="w-full pl-10 pr-4 py-3 text-sm bg-slate-950/80 border border-slate-700/80 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 rounded-xl outline-none text-white transition font-medium placeholder-slate-500"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-300 mb-1.5">
              Password
            </label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full pl-10 pr-4 py-3 text-sm bg-slate-950/80 border border-slate-700/80 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 rounded-xl outline-none text-white transition font-medium placeholder-slate-500"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 bg-gradient-to-r from-emerald-600 to-emerald-500 hover:from-emerald-500 hover:to-emerald-400 active:scale-[0.99] disabled:opacity-50 text-slate-950 font-black rounded-xl transition shadow-lg shadow-emerald-600/25 text-sm mt-3 flex items-center justify-center space-x-2 cursor-pointer"
          >
            <LogIn className="w-4 h-4" />
            <span>{loading ? 'Memverifikasi...' : 'Masuk Aplikasi'}</span>
          </button>
        </form>

        {/* Quick Fill Shortcuts for Testing */}
        <div className="pt-4 border-t border-slate-800/80 space-y-2">
          <p className="text-[11px] font-semibold text-slate-400 text-center flex items-center justify-center space-x-1">
            <Sparkles className="w-3 h-3 text-emerald-400" />
            <span>Pilih Akun Cepat (Testing):</span>
          </p>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <button
              type="button"
              onClick={() => handleQuickFill('admin')}
              className={`p-2 rounded-xl border text-center transition font-bold ${
                username === 'admin'
                  ? 'bg-emerald-500/15 border-emerald-500 text-emerald-400'
                  : 'bg-slate-950/60 border-slate-800 text-slate-300 hover:bg-slate-800'
              }`}
            >
              👑 Super Admin
            </button>
            <button
              type="button"
              onClick={() => handleQuickFill('kasir')}
              className={`p-2 rounded-xl border text-center transition font-bold ${
                username === 'kasir'
                  ? 'bg-emerald-500/15 border-emerald-500 text-emerald-400'
                  : 'bg-slate-950/60 border-slate-800 text-slate-300 hover:bg-slate-800'
              }`}
            >
              🏪 Admin Kasir
            </button>
          </div>
        </div>

        <div className="text-center text-[10px] text-slate-500">
          Apotek Santosa Farma — Pertigaan Jl. Raya Jalancagak, Subang
        </div>
      </div>
    </div>
  );
}
