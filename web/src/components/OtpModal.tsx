'use client';

import React, { useState, useEffect } from 'react';
import { API_BASE_URL } from '@/lib/api';
import { KeyRound, X, RefreshCw } from 'lucide-react';

interface OtpModalProps {
  isOpen: boolean;
  onClose: () => void;
  target: string;
  type: 'phone' | 'email';
  onSuccess: (data: any) => void;
  authToken?: string | null;
}

export default function OtpModal({ isOpen, onClose, target, type, onSuccess, authToken }: OtpModalProps) {
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [timer, setTimer] = useState(60);

  useEffect(() => {
    if (!isOpen) return;
    setTimer(60);
    const interval = setInterval(() => {
      setTimer((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(interval);
  }, [isOpen, target]);

  if (!isOpen) return null;

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (code.length !== 6) {
      setError('Kode OTP harus 6 digit angka.');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      };
      if (authToken) {
        headers['Authorization'] = `Bearer ${authToken}`;
      }

      const res = await fetch(`${API_BASE_URL}/auth/customer/verify-otp`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ target, code, type }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.message || 'Verifikasi OTP gagal.');
      }
      onSuccess(data.data);
    } catch (err: any) {
      setError(err.message || 'Terjadi kesalahan.');
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (timer > 0 || resending) return;
    setResending(true);
    setError('');
    try {
      const res = await fetch(`${API_BASE_URL}/auth/customer/resend-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ target, type }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'Gagal mengirim ulang OTP.');
      setTimer(60);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setResending(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
      <div className="bg-white rounded-3xl max-w-md w-full p-6 shadow-2xl relative animate-scale">
        <button
          onClick={onClose}
          className="absolute top-5 right-5 text-slate-400 hover:text-slate-700 p-1.5 rounded-full hover:bg-slate-100 transition"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="text-center">
          <div className="w-14 h-14 rounded-2xl bg-brand-50 text-brand-600 flex items-center justify-center mx-auto mb-3 shadow-inner">
            <KeyRound className="w-7 h-7" />
          </div>
          <h3 className="text-xl font-bold text-slate-900">Verifikasi Kode OTP</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-xs mx-auto">
            Kode 6-digit telah dikirimkan via {type === 'phone' ? 'WhatsApp' : 'Email'} ke{' '}
            <strong className="text-slate-800">{target}</strong>
          </p>
          {type === 'email' && (
            <div className="mt-3 p-2.5 bg-amber-50 border border-amber-200/80 rounded-xl text-left flex items-start space-x-2">
              <span className="text-sm flex-shrink-0">💡</span>
              <p className="text-[11px] text-amber-800 leading-snug">
                <strong>Catatan:</strong> Jika email belum muncul di Inbox, mohon periksa folder <strong>Spam</strong> atau <strong>Junk</strong> Gmail Anda.
              </p>
            </div>
          )}
        </div>

        <form onSubmit={handleVerify} className="mt-6 space-y-4">
          {error && (
            <div className="p-3 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-xl">
              {error}
            </div>
          )}

          <div>
            <input
              type="text"
              maxLength={6}
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/[^0-9]/g, ''))}
              placeholder="123456"
              className="w-full text-center text-3xl font-black tracking-widest py-3 border-2 border-slate-200 focus:border-brand-500 rounded-2xl outline-none transition"
              autoFocus
            />
          </div>

          <button
            type="submit"
            disabled={loading || code.length !== 6}
            className="w-full py-3.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold rounded-xl transition shadow-md shadow-brand-600/20"
          >
            {loading ? 'Memverifikasi...' : 'Verifikasi & Lanjutkan'}
          </button>
        </form>

        <div className="mt-5 text-center text-xs text-slate-500">
          {timer > 0 ? (
            <span>Kirim ulang kode dalam <strong className="text-slate-800">{timer} detik</strong></span>
          ) : (
            <button
              onClick={handleResend}
              disabled={resending}
              className="font-bold text-brand-600 hover:text-brand-700 flex items-center justify-center space-x-1 mx-auto"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${resending ? 'animate-spin' : ''}`} />
              <span>Kirim Ulang Kode OTP</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

