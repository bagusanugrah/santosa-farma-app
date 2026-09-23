'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { API_BASE_URL } from '@/lib/api';
import OtpModal from '@/components/OtpModal';
import { UserPlus, Smartphone, Mail, AlertCircle } from 'lucide-react';

export default function CustomerRegisterPage() {
  const router = useRouter();
  const { user, token, loading: authLoading, login } = useAuth();

  const [registerType, setRegisterType] = useState<'phone' | 'email'>('phone');
  const [name, setName] = useState('');
  const [target, setTarget] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const [showOtpModal, setShowOtpModal] = useState(false);

  useEffect(() => {
    if (authLoading) return;
    if (user && token) {
      router.replace('/');
    }
  }, [user, token, authLoading, router]);

  if (authLoading || (user && token)) {
    return (
      <div className="max-w-md mx-auto py-16 flex flex-col items-center justify-center space-y-3">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xs text-slate-500 font-medium">Memeriksa sesi...</p>
      </div>
    );
  }

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const payload: any = {
        name,
        type: registerType,
        password,
      };

      if (registerType === 'phone') {
        payload.phone = target.trim();
      } else {
        payload.email = target.trim();
      }

      const res = await fetch(`${API_BASE_URL}/auth/customer/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(payload),
      });

      const json = await res.json();
      if (!res.ok) {
        throw new Error(json.message || Object.values(json.errors || {})[0] as string || 'Registrasi gagal.');
      }

      // Open OTP Modal
      setShowOtpModal(true);
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
      router.push('/');
    }
  };

  return (
    <div className="max-w-md mx-auto py-8">
      <div className="bg-white rounded-3xl border border-slate-200 p-8 shadow-xl">
        <div className="text-center mb-6">
          <div className="w-14 h-14 rounded-2xl bg-brand-50 text-brand-600 flex items-center justify-center mx-auto mb-3 shadow-inner">
            <UserPlus className="w-7 h-7" />
          </div>
          <h2 className="text-2xl font-black text-slate-900">Daftar Akun Baru</h2>
          <p className="text-xs text-slate-500 mt-1">Buat akun untuk memesan obat online di Apotek Santosa Farma</p>
        </div>

        {/* Method Toggle: WhatsApp vs Email */}
        <div className="grid grid-cols-2 gap-2 p-1.5 bg-slate-100 rounded-2xl mb-6">
          <button
            type="button"
            onClick={() => {
              setRegisterType('phone');
              setTarget('');
              setError('');
            }}
            className={`py-2 text-xs font-bold rounded-xl transition flex items-center justify-center space-x-1.5 ${
              registerType === 'phone'
                ? 'bg-white text-brand-700 shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Smartphone className="w-4 h-4" />
            <span>Nomor WhatsApp</span>
          </button>
          <button
            type="button"
            onClick={() => {
              setRegisterType('email');
              setTarget('');
              setError('');
            }}
            className={`py-2 text-xs font-bold rounded-xl transition flex items-center justify-center space-x-1.5 ${
              registerType === 'email'
                ? 'bg-white text-brand-700 shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Mail className="w-4 h-4" />
            <span>Alamat Email</span>
          </button>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-2xl flex items-center space-x-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleRegister} className="space-y-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1.5">Nama Lengkap</label>
            <input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Contoh: Siti Rahmah"
              className="w-full px-4 py-3 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium"
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1.5">
              {registerType === 'phone' ? 'Nomor WhatsApp Aktif' : 'Alamat Email'}
            </label>
            <input
              type={registerType === 'phone' ? 'tel' : 'email'}
              required
              value={target}
              onChange={(e) => setTarget(e.target.value)}
              placeholder={registerType === 'phone' ? '081234567890' : 'siti@example.com'}
              className="w-full px-4 py-3 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium"
            />
            <p className="text-[11px] text-slate-400 mt-1">
              Kode verifikasi OTP 6-digit akan dikirimkan ke {registerType === 'phone' ? 'WhatsApp' : 'Email'} ini.
            </p>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1.5">Password</label>
            <input
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Minimal 6 karakter"
              className="w-full px-4 py-3 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold rounded-xl transition shadow-lg shadow-brand-600/20 text-sm mt-4"
          >
            {loading ? 'Mengirim OTP...' : 'Daftar & Kirim OTP'}
          </button>
        </form>

        <div className="mt-8 pt-6 border-t border-slate-100 text-center text-xs text-slate-500">
          Sudah punya akun?{' '}
          <Link href="/login" className="font-bold text-brand-600 hover:text-brand-700">
            Masuk di sini
          </Link>
        </div>
      </div>

      <OtpModal
        isOpen={showOtpModal}
        onClose={() => setShowOtpModal(false)}
        target={target.trim()}
        type={registerType}
        onSuccess={handleOtpVerified}
      />
    </div>
  );
}

