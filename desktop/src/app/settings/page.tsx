'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useStaffAuth } from '@/context/StaffAuthContext';
import { useStoreStatus } from '@/context/StoreStatusContext';
import { changeStaffPassword } from '@/lib/api';
import {
  Settings,
  Globe,
  Lock,
  KeyRound,
  ShieldAlert,
  AlertTriangle,
  CheckCircle2,
  AlertCircle,
  Eye,
  EyeOff,
  UserCheck,
  RefreshCw,
  X,
  Check,
} from 'lucide-react';

export default function SettingsPage() {
  const router = useRouter();
  const { user, token, loading: authLoading } = useStaffAuth();
  const {
    onlineOrdersEnabled,
    toggling,
    setOnlineOrdersState,
    statusMessage,
  } = useStoreStatus();

  // Change password form state
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newPasswordConfirmation, setNewPasswordConfirmation] = useState('');
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [passwordSuccess, setPasswordSuccess] = useState('');

  // Confirmation modal state for activating online orders
  const [showConfirmModal, setShowConfirmModal] = useState(false);

  useEffect(() => {
    if (authLoading) return;
    if (!user || !token) {
      router.replace('/login');
    }
  }, [user, token, authLoading, router]);

  if (authLoading || !user || !token) {
    return (
      <div className="flex-1 flex items-center justify-center p-8 text-slate-400 font-medium text-sm">
        <RefreshCw className="w-5 h-5 animate-spin mr-2" />
        Memuat pengaturan...
      </div>
    );
  }

  // Handle toggle click
  const handleToggleClick = () => {
    if (toggling) return;

    if (!onlineOrdersEnabled) {
      // Trying to activate -> Show confirmation modal first!
      setShowConfirmModal(true);
    } else {
      // Deactivating -> can be done directly or confirmed
      setOnlineOrdersState(false);
    }
  };

  const handleConfirmActivate = async () => {
    setShowConfirmModal(false);
    await setOnlineOrdersState(true);
  };

  // Handle password change
  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError('');
    setPasswordSuccess('');

    if (newPassword.length < 6) {
      setPasswordError('Password baru minimal harus 6 karakter.');
      return;
    }

    if (newPassword !== newPasswordConfirmation) {
      setPasswordError('Konfirmasi password baru tidak cocok.');
      return;
    }

    setPasswordLoading(true);
    try {
      const res = await changeStaffPassword(token, {
        current_password: currentPassword,
        new_password: newPassword,
        new_password_confirmation: newPasswordConfirmation,
      });

      if (!res.success) {
        throw new Error(res.message);
      }

      setPasswordSuccess('Password akun Anda berhasil diperbarui! Gunakan password baru ini saat login berikutnya.');
      setCurrentPassword('');
      setNewPassword('');
      setNewPasswordConfirmation('');
      setTimeout(() => setPasswordSuccess(''), 6000);
    } catch (err: any) {
      setPasswordError(err.message || 'Terjadi kesalahan saat mengubah password.');
    } finally {
      setPasswordLoading(false);
    }
  };

  return (
    <div className="flex-1 p-8 space-y-8 max-w-5xl mx-auto w-full animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-200 pb-5">
        <div className="flex items-center space-x-3">
          <div className="w-12 h-12 rounded-2xl bg-brand-600 text-white flex items-center justify-center shadow-lg shadow-brand-600/20">
            <Settings className="w-6 h-6" />
          </div>
          <div>
            <h1 className="text-2xl font-black text-slate-900 tracking-tight">Pengaturan Sistem</h1>
            <p className="text-xs text-slate-500 font-medium mt-0.5">
              Kelola keamanan akun kasir/admin serta kontrol status pemesanan obat online.
            </p>
          </div>
        </div>

        {/* User Role Badge */}
        <div className="flex items-center space-x-3 px-4 py-2 bg-white rounded-2xl border border-slate-200 shadow-xs">
          <div className="w-8 h-8 rounded-xl bg-brand-50 text-brand-700 flex items-center justify-center font-black text-xs">
            {user.name.charAt(0).toUpperCase()}
          </div>
          <div>
            <span className="text-xs font-bold text-slate-800 block leading-tight">{user.name}</span>
            <span className="text-[10px] font-semibold text-slate-400 capitalize">
              {user.role === 'super_admin' ? 'Super Admin' : 'Admin Kasir'} • @{user.username}
            </span>
          </div>
        </div>
      </div>

      {statusMessage && (
        <div className="p-4 bg-emerald-50 border border-emerald-300 text-emerald-900 rounded-2xl text-xs font-bold flex items-center space-x-2 shadow-xs animate-fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
          <span>{statusMessage}</span>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* ============================================================ */}
        {/* SECTION 1: Online Store Toggle Control */}
        {/* ============================================================ */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 sm:p-7 shadow-sm flex flex-col justify-between space-y-6">
          <div>
            <div className="flex items-center space-x-3 mb-4">
              <div
                className={`w-10 h-10 rounded-2xl flex items-center justify-center transition ${
                  onlineOrdersEnabled
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-amber-100 text-amber-700'
                }`}
              >
                <Globe className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-extrabold text-base text-slate-900">Layanan Beli Obat di Web</h3>
                <p className="text-xs text-slate-400">Kontrol fitur pemesanan obat online untuk pelanggan</p>
              </div>
            </div>

            <div className="space-y-4">
              <p className="text-xs text-slate-600 leading-relaxed">
                Fitur ini mengatur apakah pelanggan di luar toko dapat melakukan transaksi pembelian obat secara online melalui web:
              </p>

              <div className="space-y-2.5 text-xs">
                <div
                  className={`p-3.5 rounded-2xl border transition-all ${
                    onlineOrdersEnabled
                      ? 'bg-emerald-50/70 border-emerald-200 text-emerald-950 font-medium'
                      : 'bg-slate-50 border-slate-200 text-slate-500'
                  }`}
                >
                  <strong className="text-emerald-800 block mb-0.5">● Mode AKTIF (Menerima Order Web):</strong>
                  Pelanggan dapat membuat akun, login, memilih obat, dan melakukan pembayaran/checkout online via QRIS atau Transfer Bank.
                </div>

                <div
                  className={`p-3.5 rounded-2xl border transition-all ${
                    !onlineOrdersEnabled
                      ? 'bg-amber-50/70 border-amber-200 text-amber-950 font-medium'
                      : 'bg-slate-50 border-slate-200 text-slate-500'
                  }`}
                >
                  <strong className="text-amber-800 block mb-0.5">● Mode NONAKTIF (Katalog Etalase Saja):</strong>
                  Pelanggan di web hanya bisa mengecek ketersediaan obat dan daftar harga. Fitur beli obat, login, dan pendaftaran akun ditutup sementara agar kasir fokus pada transaksi di apotek.
                </div>
              </div>
            </div>
          </div>

          {/* Interactive Toggle Switch */}
          <div className="pt-6 border-t border-slate-100 flex items-center justify-between gap-4">
            <div>
              <span className="text-xs font-black text-slate-900 block mb-1">
                Status Pemesanan Online Saat Ini:
              </span>
              <span
                className={`inline-flex items-center space-x-1.5 px-3 py-1 rounded-xl text-xs font-black tracking-wide border ${
                  onlineOrdersEnabled
                    ? 'bg-emerald-100 text-emerald-900 border-emerald-300'
                    : 'bg-slate-100 text-slate-700 border-slate-300'
                }`}
              >
                <span
                  className={`w-2 h-2 rounded-full ${
                    onlineOrdersEnabled ? 'bg-emerald-600 animate-pulse' : 'bg-slate-400'
                  }`}
                />
                <span>{onlineOrdersEnabled ? 'AKTIF (Menerima Order Web)' : 'NONAKTIF (Etalase Saja)'}</span>
              </span>
            </div>

            {/* Toggle Switch Component */}
            <div className="flex items-center space-x-2">
              <button
                type="button"
                role="switch"
                aria-checked={onlineOrdersEnabled}
                onClick={handleToggleClick}
                disabled={toggling}
                className={`relative inline-flex h-8 w-16 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-300 ease-in-out focus:outline-none shadow-inner ${
                  onlineOrdersEnabled ? 'bg-emerald-500' : 'bg-slate-300'
                } disabled:opacity-50 disabled:cursor-not-allowed`}
                title={onlineOrdersEnabled ? 'Klik untuk mematikan pembelian online' : 'Klik untuk mengaktifkan pembelian online'}
              >
                <span className="sr-only">Toggle Layanan Web</span>
                <span
                  aria-hidden="true"
                  className={`pointer-events-none inline-flex items-center justify-center h-7 w-7 transform rounded-full bg-white shadow-md ring-0 transition duration-300 ease-in-out ${
                    onlineOrdersEnabled ? 'translate-x-8 text-emerald-600' : 'translate-x-0 text-slate-400'
                  }`}
                >
                  {toggling ? (
                    <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                  ) : onlineOrdersEnabled ? (
                    <Check className="w-3.5 h-3.5 stroke-[3]" />
                  ) : (
                    <X className="w-3.5 h-3.5 stroke-[3]" />
                  )}
                </span>
              </button>
            </div>
          </div>
        </div>

        {/* ============================================================ */}
        {/* SECTION 2: Change Password Form */}
        {/* ============================================================ */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 sm:p-7 shadow-sm space-y-6">
          <div className="flex items-center space-x-3 mb-2">
            <div className="w-10 h-10 rounded-2xl bg-brand-50 text-brand-700 flex items-center justify-center shadow-inner">
              <KeyRound className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-extrabold text-base text-slate-900">Ganti Password Akun</h3>
              <p className="text-xs text-slate-400">
                Perbarui kata sandi untuk akun <strong className="text-slate-700">@{user.username}</strong>
              </p>
            </div>
          </div>

          {passwordError && (
            <div className="p-3.5 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-2xl flex items-center space-x-2 animate-fade-in">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span>{passwordError}</span>
            </div>
          )}

          {passwordSuccess && (
            <div className="p-3.5 bg-emerald-50 border border-emerald-300 text-emerald-900 text-xs font-semibold rounded-2xl flex items-center space-x-2 animate-fade-in">
              <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
              <span>{passwordSuccess}</span>
            </div>
          )}

          <form onSubmit={handleChangePassword} className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Password Saat Ini
              </label>
              <div className="relative">
                <input
                  type={showCurrentPassword ? 'text' : 'password'}
                  required
                  value={currentPassword}
                  onChange={(e) => setCurrentPassword(e.target.value)}
                  placeholder="Masukkan password saat ini"
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowCurrentPassword(!showCurrentPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition"
                >
                  {showCurrentPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Password Baru (Min. 6 Karakter)
              </label>
              <div className="relative">
                <input
                  type={showNewPassword ? 'text' : 'password'}
                  required
                  minLength={6}
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Masukkan password baru"
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowNewPassword(!showNewPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition"
                >
                  {showNewPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Konfirmasi Password Baru
              </label>
              <div className="relative">
                <input
                  type={showConfirmPassword ? 'text' : 'password'}
                  required
                  minLength={6}
                  value={newPasswordConfirmation}
                  onChange={(e) => setNewPasswordConfirmation(e.target.value)}
                  placeholder="Ulangi password baru"
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition"
                >
                  {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <div className="pt-2">
              <button
                type="submit"
                disabled={passwordLoading || !currentPassword || !newPassword || !newPasswordConfirmation}
                className="w-full py-3 bg-brand-600 hover:bg-brand-700 disabled:opacity-40 text-white font-extrabold text-xs rounded-xl transition flex items-center justify-center space-x-2 shadow-md shadow-brand-600/20"
              >
                {passwordLoading ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Menyimpan Password...</span>
                  </>
                ) : (
                  <>
                    <Lock className="w-4 h-4" />
                    <span>Simpan Password Baru</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>

      {/* ============================================================ */}
      {/* CONFIRMATION POPUP MODAL (BEFORE ACTIVATING ONLINE ORDERS) */}
      {/* ============================================================ */}
      {showConfirmModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-3xl max-w-md w-full p-6 shadow-2xl relative animate-scale border border-slate-100">
            <button
              onClick={() => setShowConfirmModal(false)}
              className="absolute top-5 right-5 text-slate-400 hover:text-slate-600 p-1.5 rounded-full hover:bg-slate-100 transition"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="w-14 h-14 rounded-2xl bg-amber-100 text-amber-700 flex items-center justify-center mx-auto mb-4 shadow-inner">
              <AlertTriangle className="w-7 h-7" />
            </div>

            <h3 className="text-lg font-black text-slate-900 text-center">
              Konfirmasi Aktifkan Pembelian di Web
            </h3>

            <p className="text-xs text-slate-600 mt-2 text-center leading-relaxed">
              Apakah Anda yakin ingin <strong>MENGAKTIFKAN</strong> layanan pemesanan obat online di web?
            </p>

            <div className="mt-4 p-3.5 bg-amber-50/80 rounded-2xl border border-amber-200/80 text-[11px] text-amber-900 leading-relaxed">
              <strong>PENTING:</strong> Setelah diaktifkan, pelanggan di website akan dapat langsung checkout dan membayar obat secara online. Pastikan kasir siap menerima pesanan masuk agar antrean apotek tetap tertib.
            </div>

            <div className="mt-6 grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setShowConfirmModal(false)}
                className="py-2.5 px-4 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition"
              >
                Batal
              </button>
              <button
                type="button"
                onClick={handleConfirmActivate}
                disabled={toggling}
                className="py-2.5 px-4 bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs rounded-xl shadow-md shadow-emerald-600/20 transition flex items-center justify-center space-x-1.5"
              >
                {toggling ? (
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <Check className="w-3.5 h-3.5" />
                )}
                <span>Ya, Aktifkan</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
