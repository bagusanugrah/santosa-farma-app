'use client';

import React, { useState, useEffect, Suspense } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { API_BASE_URL } from '@/lib/api';
import OtpModal from '@/components/OtpModal';
import { LogIn, AlertCircle } from 'lucide-react';

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectUrl = searchParams.get('redirect') || '/';
  const { user, token, loading: authLoading, login } = useAuth();

  const [contactInput, setContactInput] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Unverified OTP fallback modal
  const [showOtpModal, setShowOtpModal] = useState(false);
  const [otpTarget, setOtpTarget] = useState('');
  const [otpType, setOtpType] = useState<'phone' | 'email'>('phone');

  useEffect(() => {
    if (authLoading) return;
    if (user && token) {
      router.replace(redirectUrl);
    }
  }, [user, token, authLoading, redirectUrl, router]);

  if (authLoading || (user && token)) {
    return (
      <div className="max-w-md mx-auto py-16 flex flex-col items-center justify-center space-y-3">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xs text-slate-500 font-medium">Memeriksa sesi...</p>
      </div>
    );
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const res = await fetch(`${API_BASE_URL}/auth/customer/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          login: contactInput.trim(),
          password,
        }),
      });

      const json = await res.json();

      if (!res.ok) {
        if (json.require_verification) {
          setOtpTarget(json.target);
          setOtpType(json.type);
          setShowOtpModal(true);
          throw new Error(json.message);
        }
        throw new Error(json.message || 'Login gagal.');
      }

      login(json.data.token, json.data.customer);
      router.push(redirectUrl);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleOtpVerified = (data: any) => {
    setShowOtpModal(false);
    if (data?.token && data?.customer) {
      login(data.token, data.customer);
      router.push(redirectUrl);
    }
  };

  return (
    <div className="max-w-md mx-auto py-8">
      <div className="bg-white rounded-3xl border border-slate-200 p-8 shadow-xl">
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-brand-50 text-brand-600 flex items-center justify-center mx-auto mb-3 shadow-inner">
            <LogIn className="w-7 h-7" />
          </div>
          <h2 className="text-2xl font-black text-slate-900">Masuk Akun</h2>
          <p className="text-xs text-slate-500 mt-1">Masuk dengan Nomor HP atau Email terdaftar</p>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-2xl flex items-center space-x-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1.5">No. WhatsApp atau Email</label>
            <input
              type="text"
              required
              value={contactInput}
              onChange={(e) => setContactInput(e.target.value)}
              placeholder="08123456789 atau email@domain.com"
              className="w-full px-4 py-3 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium"
            />
          </div>

          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-bold text-slate-700">Password</label>
              <Link href="/forgot-password" className="text-xs font-bold text-brand-600 hover:text-brand-700">
                Lupa Password?
              </Link>
            </div>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full px-4 py-3 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold rounded-xl transition shadow-lg shadow-brand-600/20 text-sm mt-2"
          >
            {loading ? 'Memproses...' : 'Masuk Sekarang'}
          </button>
        </form>

        <div className="mt-8 pt-6 border-t border-slate-100 text-center text-xs text-slate-500">
          Belum punya akun?{' '}
          <Link href="/register" className="font-bold text-brand-600 hover:text-brand-700">
            Daftar Sekarang
          </Link>
        </div>
      </div>

      <OtpModal
        isOpen={showOtpModal}
        onClose={() => setShowOtpModal(false)}
        target={otpTarget}
        type={otpType}
        onSuccess={handleOtpVerified}
      />
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="text-center py-12 text-sm text-slate-400">Memuat...</div>}>
      <LoginForm />
    </Suspense>
  );
}

