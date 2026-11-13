'use client';

import React, { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { useStaffAuth } from '@/context/StaffAuthContext';
import { useStoreStatus } from '@/context/StoreStatusContext';
import {
  changeStaffPassword,
  exportDatabaseBackup,
  importDatabaseBackup,
} from '@/lib/api';
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
  Database,
  Download,
  Upload,
  FileJson,
  FileArchive,
  RotateCcw,
  ShieldCheck,
  Info,
  Trash2,
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

  // Database Backup & Restore state (Super Admin only)
  const [exportLoading, setExportLoading] = useState(false);
  const [exportSuccess, setExportSuccess] = useState('');
  const [exportError, setExportError] = useState('');

  const [importFile, setImportFile] = useState<File | null>(null);
  const [importLoading, setImportLoading] = useState(false);
  const [importSuccess, setImportSuccess] = useState('');
  const [importError, setImportError] = useState('');
  const [showImportConfirmModal, setShowImportConfirmModal] = useState(false);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

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

  // Handle toggle click for web orders
  const handleToggleClick = () => {
    if (toggling) return;

    if (!onlineOrdersEnabled) {
      // Trying to activate -> Show confirmation modal first!
      setShowConfirmModal(true);
    } else {
      // Deactivating -> can be done directly
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

  // Handle Export Database Backup
  const handleExportDatabase = async () => {
    setExportError('');
    setExportSuccess('');
    setExportLoading(true);

    try {
      const res = await exportDatabaseBackup(token);
      if (!res.success) {
        throw new Error(res.message || 'Gagal mengekspor file cadangan.');
      }
      setExportSuccess(`File backup database berhasil diunduh: ${res.filename}`);
      setTimeout(() => setExportSuccess(''), 8000);
    } catch (err: any) {
      setExportError(err.message || 'Terjadi kesalahan saat mengekspor database.');
    } finally {
      setExportLoading(false);
    }
  };

  // Handle File Selection for Import
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setImportError('');
    setImportSuccess('');

    const file = e.target.files?.[0];
    if (!file) return;

    const lowerName = file.name.toLowerCase();
    if (!lowerName.endsWith('.zip') && !lowerName.endsWith('.json')) {
      setImportError('Format berkas tidak didukung! Harap pilih berkas cadangan resmi berformat .zip (disarankan) atau .json');
      setImportFile(null);
      if (fileInputRef.current) fileInputRef.current.value = '';
      return;
    }

    setImportFile(file);
  };

  const handleResetImportFile = () => {
    setImportFile(null);
    setImportError('');
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  // Handle Opening Confirmation Modal for Import
  const handleInitiateImport = () => {
    if (!importFile) {
      setImportError('Silakan pilih berkas cadangan (.zip atau .json) terlebih dahulu.');
      return;
    }
    setImportError('');
    setImportSuccess('');
    setShowImportConfirmModal(true);
  };

  // Execute Database Restore after Confirmation
  const handleExecuteRestore = async () => {
    setShowImportConfirmModal(false);
    if (!importFile) return;

    setImportLoading(true);
    setImportError('');
    setImportSuccess('');

    try {
      const res = await importDatabaseBackup(token, importFile);
      if (!res.success) {
        throw new Error(res.message || 'Gagal memulihkan database.');
      }

      const counts = res.data?.counts || {};
      const restoredImages = res.data?.restored_images ?? 0;
      const summaryText = Object.entries(counts)
        .map(([tbl, count]) => `${count} ${tbl}`)
        .join(', ');

      setImportSuccess(
        `Database dan media berhasil dipulihkan secara penuh! Data: ${summaryText || 'seluruh data'}, ${restoredImages} foto produk dipulihkan, dan penyimpanan storage dibersihkan dari file lama/stuck.`
      );
      handleResetImportFile();
    } catch (err: any) {
      setImportError(err.message || 'Gagal memulihkan cadangan. Berkas tidak sesuai format atau korup.');
    } finally {
      setImportLoading(false);
    }
  };

  const isSuperAdmin = user.role === 'super_admin';

  return (
    <div className="flex-1 p-8 space-y-8 max-w-5xl mx-auto w-full animate-fade-in pb-16">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-200 pb-5">
        <div className="flex items-center space-x-3">
          <div className="w-12 h-12 rounded-2xl bg-brand-600 text-white flex items-center justify-center shadow-lg shadow-brand-600/20">
            <Settings className="w-6 h-6" />
          </div>
          <div>
            <h1 className="text-2xl font-black text-slate-900 tracking-tight">Pengaturan Sistem</h1>
            <p className="text-xs text-slate-500 font-medium mt-0.5">
              Kelola keamanan akun kasir/admin, kontrol toko online, dan sistem backup database.
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
              {isSuperAdmin ? 'Super Admin' : 'Admin Kasir'} • @{user.username}
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

      {/* Grid 2 Kolom Bagian Atas */}
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
                  Pelanggan dapat membuat akun, login, memilih obat, dan melakukan pembayaran online via QRIS atau Transfer Bank.
                </div>

                <div
                  className={`p-3.5 rounded-2xl border transition-all ${
                    !onlineOrdersEnabled
                      ? 'bg-amber-50/70 border-amber-200 text-amber-950 font-medium'
                      : 'bg-slate-50 border-slate-200 text-slate-500'
                  }`}
                >
                  <strong className="text-amber-800 block mb-0.5">● Mode NONAKTIF (Katalog Etalase Saja):</strong>
                  Pelanggan di web hanya bisa mengecek ketersediaan obat dan daftar harga. Fitur beli obat dan pendaftaran akun ditutup sementara.
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
      {/* SECTION 3: DATABASE BACKUP & RESTORE (SUPER ADMIN ONLY)       */}
      {/* ============================================================ */}
      <div className="bg-white rounded-3xl border border-slate-200 p-6 sm:p-8 shadow-sm space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-4 border-b border-slate-100 gap-3">
          <div className="flex items-center space-x-3">
            <div className="w-11 h-11 rounded-2xl bg-indigo-50 text-indigo-700 flex items-center justify-center shadow-inner">
              <Database className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="font-black text-lg text-slate-900">Backup & Restore Database</h3>
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider bg-indigo-100 text-indigo-800 border border-indigo-200">
                  Super Admin
                </span>
              </div>
              <p className="text-xs text-slate-500 font-medium mt-0.5">
                Cadangkan seluruh data apotek (pengguna, password, produk, transaksi, riwayat) atau pulihkan dari file resmi.
              </p>
            </div>
          </div>
        </div>

        {!isSuperAdmin ? (
          <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 flex items-center space-x-3 text-slate-600 text-xs">
            <ShieldAlert className="w-5 h-5 text-amber-600 flex-shrink-0" />
            <span>
              Fitur pencadangan dan pemulihan database dibatasi. Hanya akun dengan hak akses <strong>Super Admin</strong> yang dapat mengekspor atau mengimpor data database.
            </span>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Global Alerts for Backup/Restore */}
            {exportSuccess && (
              <div className="p-4 bg-emerald-50 border border-emerald-300 text-emerald-900 rounded-2xl text-xs font-bold flex items-center space-x-2 animate-fade-in shadow-xs">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                <span>{exportSuccess}</span>
              </div>
            )}
            {exportError && (
              <div className="p-4 bg-red-50 border border-red-300 text-red-700 rounded-2xl text-xs font-semibold flex items-center space-x-2 animate-fade-in shadow-xs">
                <AlertCircle className="w-4 h-4 text-red-600 flex-shrink-0" />
                <span>{exportError}</span>
              </div>
            )}

            {importSuccess && (
              <div className="p-4 bg-emerald-50 border border-emerald-300 text-emerald-900 rounded-2xl text-xs font-bold flex items-center space-x-2 animate-fade-in shadow-xs">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                <span>{importSuccess}</span>
              </div>
            )}
            {importError && (
              <div className="p-4 bg-red-50 border border-red-300 text-red-700 rounded-2xl text-xs font-semibold flex items-center space-x-2 animate-fade-in shadow-xs">
                <AlertCircle className="w-4 h-4 text-red-600 flex-shrink-0" />
                <span>{importError}</span>
              </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Card 1: Export Database & Media */}
              <div className="p-5 sm:p-6 bg-slate-50/70 rounded-2xl border border-slate-200 flex flex-col justify-between space-y-5 hover:border-slate-300 transition">
                <div className="space-y-3">
                  <div className="flex items-center space-x-2.5">
                    <div className="w-8 h-8 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center">
                      <Download className="w-4 h-4" />
                    </div>
                    <h4 className="font-black text-sm text-slate-800">1. Ekspor Paket Cadangan Lengkap (.zip)</h4>
                  </div>
                  <p className="text-xs text-slate-600 leading-relaxed">
                    Unduh paket lengkap 100% database apotek beserta seluruh file foto produk ke dalam satu arsip ZIP resmi:
                  </p>
                  <ul className="text-[11px] text-slate-500 space-y-1 list-disc list-inside">
                    <li>Akun kasir & super admin (password terenkripsi tetap utuh)</li>
                    <li>Seluruh data obat, kategori, harga, dan file gambar/foto produk di storage</li>
                    <li>Semua transaksi kasir (POS), transaksi web, dan item penjualan</li>
                    <li>Pengaturan operasional toko & data pelanggan online</li>
                  </ul>
                  <div className="p-2.5 bg-blue-50/70 rounded-xl border border-blue-200/80 text-[11px] text-blue-900 flex items-center space-x-2">
                    <ShieldCheck className="w-4 h-4 text-blue-600 flex-shrink-0" />
                    <span>Dilengkapi berkas manifest dan checksum SHA-256 untuk menjamin integritas.</span>
                  </div>
                </div>

                <div>
                  <button
                    type="button"
                    onClick={handleExportDatabase}
                    disabled={exportLoading}
                    className="w-full py-3 px-4 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white font-extrabold text-xs rounded-xl shadow-md shadow-indigo-600/20 transition flex items-center justify-center space-x-2 cursor-pointer"
                  >
                    {exportLoading ? (
                      <>
                        <RefreshCw className="w-4 h-4 animate-spin" />
                        <span>Mengemas Paket Cadangan...</span>
                      </>
                    ) : (
                      <>
                        <FileArchive className="w-4 h-4" />
                        <span>Unduh Paket Cadangan Lengkap (.zip)</span>
                      </>
                    )}
                  </button>
                </div>
              </div>

              {/* Card 2: Import & Restore Database & Media */}
              <div className="p-5 sm:p-6 bg-slate-50/70 rounded-2xl border border-slate-200 flex flex-col justify-between space-y-5 hover:border-slate-300 transition">
                <div className="space-y-3">
                  <div className="flex items-center space-x-2.5">
                    <div className="w-8 h-8 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center">
                      <Upload className="w-4 h-4" />
                    </div>
                    <h4 className="font-black text-sm text-slate-800">2. Impor & Pulihkan Sistem (.zip)</h4>
                  </div>
                  <p className="text-xs text-slate-600 leading-relaxed">
                    Pulihkan seluruh sistem dengan mengunggah arsip paket cadangan resmi (.zip atau berkas .json).
                  </p>

                  <div className="p-2.5 bg-amber-50/80 rounded-xl border border-amber-200/80 text-[11px] text-amber-900 flex items-start space-x-2">
                    <AlertTriangle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                    <span>
                      <strong>Perhatian:</strong> Data yang saat ini sedang berjalan akan <strong>DITIMPA</strong> secara menyeluruh. File foto lama/stuck di storage akan dibersihkan dan dipulihkan sesuai paket backup.
                    </span>
                  </div>

                  {/* File Selector */}
                  <div className="space-y-2">
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept=".zip,.json,application/zip,application/x-zip-compressed,application/json"
                      onChange={handleFileChange}
                      className="hidden"
                      id="db-backup-file-input"
                    />

                    {!importFile ? (
                      <label
                        htmlFor="db-backup-file-input"
                        className="w-full border-2 border-dashed border-slate-300 hover:border-indigo-400 bg-white p-4 rounded-xl flex flex-col items-center justify-center cursor-pointer transition text-center group"
                      >
                        <FileArchive className="w-6 h-6 text-slate-400 group-hover:text-indigo-600 transition mb-1" />
                        <span className="text-xs font-bold text-slate-700 group-hover:text-indigo-600">
                          Pilih Berkas Cadangan (.zip / .json)
                        </span>
                        <span className="text-[10px] text-slate-400 mt-0.5">
                          Format resmi .zip (berisi database + foto) atau .json
                        </span>
                      </label>
                    ) : (
                      <div className="p-3 bg-white border border-slate-200 rounded-xl flex items-center justify-between">
                        <div className="flex items-center space-x-2.5 min-w-0">
                          {importFile.name.toLowerCase().endsWith('.zip') ? (
                            <FileArchive className="w-5 h-5 text-indigo-600 flex-shrink-0" />
                          ) : (
                            <FileJson className="w-5 h-5 text-indigo-600 flex-shrink-0" />
                          )}
                          <div className="min-w-0">
                            <span className="text-xs font-bold text-slate-800 truncate block">
                              {importFile.name}
                            </span>
                            <span className="text-[10px] text-slate-400">
                              {(importFile.size / 1024).toFixed(1)} KB
                            </span>
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={handleResetImportFile}
                          className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition"
                          title="Hapus pilihan file"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    )}
                  </div>
                </div>

                <div>
                  <button
                    type="button"
                    onClick={handleInitiateImport}
                    disabled={!importFile || importLoading}
                    className="w-full py-3 px-4 bg-amber-600 hover:bg-amber-700 disabled:opacity-40 text-white font-extrabold text-xs rounded-xl shadow-md shadow-amber-600/20 transition flex items-center justify-center space-x-2 cursor-pointer"
                  >
                    {importLoading ? (
                      <>
                        <RefreshCw className="w-4 h-4 animate-spin" />
                        <span>Memulihkan Sistem...</span>
                      </>
                    ) : (
                      <>
                        <RotateCcw className="w-4 h-4" />
                        <span>Pulihkan Database & Foto Dari Berkas Ini</span>
                      </>
                    )}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* ============================================================ */}
      {/* CONFIRMATION POPUP MODAL (BEFORE ACTIVATING ONLINE ORDERS)   */}
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

      {/* ============================================================ */}
      {/* CONFIRMATION POPUP MODAL (BEFORE IMPORTING / OVERWRITING DB) */}
      {/* ============================================================ */}
      {showImportConfirmModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-3xl max-w-lg w-full p-6 sm:p-7 shadow-2xl relative animate-scale border border-red-100">
            <button
              onClick={() => setShowImportConfirmModal(false)}
              className="absolute top-5 right-5 text-slate-400 hover:text-slate-600 p-1.5 rounded-full hover:bg-slate-100 transition"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="w-14 h-14 rounded-2xl bg-red-100 text-red-600 flex items-center justify-center mx-auto mb-4 shadow-inner">
              <AlertTriangle className="w-7 h-7" />
            </div>

            <h3 className="text-lg font-black text-slate-900 text-center">
              Peringatan: Konfirmasi Timpa Database & Media
            </h3>

            <p className="text-xs text-slate-600 mt-2 text-center leading-relaxed">
              Anda akan memulihkan data sistem dari berkas paket cadangan:
            </p>

            <div className="mt-3 p-3 bg-slate-100 rounded-xl border border-slate-200 flex items-center space-x-2.5">
              {importFile?.name.toLowerCase().endsWith('.zip') ? (
                <FileArchive className="w-5 h-5 text-indigo-600 flex-shrink-0" />
              ) : (
                <FileJson className="w-5 h-5 text-indigo-600 flex-shrink-0" />
              )}
              <div className="min-w-0 flex-1">
                <span className="text-xs font-bold text-slate-800 block truncate">
                  {importFile?.name}
                </span>
                <span className="text-[10px] text-slate-500">
                  Ukuran berkas: {importFile ? (importFile.size / 1024).toFixed(1) : 0} KB
                </span>
              </div>
            </div>

            <div className="mt-4 p-3.5 bg-red-50/90 rounded-2xl border border-red-200 text-[11px] text-red-900 leading-relaxed space-y-1">
              <strong className="block text-red-950 font-black">
                ⚠️ TINDAKAN INI BERSIFAT PERMANEN & AKAN MENIMPA DATA!
              </strong>
              <span>
                Seluruh data yang sedang berjalan saat ini (produk, stok, transaksi kasir & online, daftar akun, dan password) akan <strong>DIHAPUS DAN DIGANTIKAN SEPENUHNYA</strong>. Seluruh file gambar lama/stuck di folder storage juga akan dibersihkan dan dipulihkan dari paket cadangan ini.
              </span>
            </div>

            <div className="mt-6 grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setShowImportConfirmModal(false)}
                className="py-3 px-4 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition cursor-pointer"
              >
                Batal, Jangan Timpa
              </button>
              <button
                type="button"
                onClick={handleExecuteRestore}
                disabled={importLoading}
                className="py-3 px-4 bg-red-600 hover:bg-red-700 text-white font-extrabold text-xs rounded-xl shadow-md shadow-red-600/20 transition flex items-center justify-center space-x-1.5 cursor-pointer"
              >
                {importLoading ? (
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <RotateCcw className="w-3.5 h-3.5" />
                )}
                <span>Ya, Timpa & Pulihkan Sistem</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
