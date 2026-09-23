'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { API_BASE_URL } from '@/lib/api';
import OtpModal from '@/components/OtpModal';
import {
  Smartphone,
  Mail,
  CheckCircle,
  AlertCircle,
  Save,
  ShieldCheck,
  Lock,
  Eye,
  EyeOff,
  Edit3,
  X,
} from 'lucide-react';

export default function ProfilePage() {
  const router = useRouter();
  const { user, token, loading, login, refreshProfile } = useAuth();

  const [name, setName] = useState('');
  const [updatingName, setUpdatingName] = useState(false);
  const [nameSuccess, setNameSuccess] = useState(false);

  // Edit / Add contact states
  const [editingPhone, setEditingPhone] = useState(false);
  const [phoneInput, setPhoneInput] = useState('');
  const [editingEmail, setEditingEmail] = useState(false);
  const [emailInput, setEmailInput] = useState('');
  const [contactType, setContactType] = useState<'phone' | 'email'>('phone');
  const [activeContactTarget, setActiveContactTarget] = useState('');
  const [addingContact, setAddingContact] = useState(false);
  const [contactError, setContactError] = useState('');
  const [showOtpModal, setShowOtpModal] = useState(false);

  // Change password states
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [passwordSuccess, setPasswordSuccess] = useState('');

  useEffect(() => {
    if (loading) return;

    if (!token || !user) {
      router.replace('/login?redirect=/profile');
      return;
    }

    if (user) {
      setName(user.name);
    }
  }, [user, token, loading, router]);

  if (loading) {
    return (
      <div className="max-w-2xl mx-auto py-16 flex flex-col items-center justify-center space-y-3">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xs text-slate-500 font-medium">Memuat profil...</p>
      </div>
    );
  }

  if (!token || !user) {
    return null;
  }

  const handleUpdateName = async (e: React.FormEvent) => {
    e.preventDefault();
    setUpdatingName(true);
    setNameSuccess(false);

    try {
      const res = await fetch(`${API_BASE_URL}/auth/customer/profile`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ name }),
      });
      if (!res.ok) throw new Error('Gagal memperbarui profil.');
      await refreshProfile();
      setNameSuccess(true);
      setTimeout(() => setNameSuccess(false), 3000);
    } catch (err: any) {
      alert(err.message);
    } finally {
      setUpdatingName(false);
    }
  };

  const handleRequestChangeContact = async (type: 'phone' | 'email', targetVal: string) => {
    const trimmed = targetVal.trim();
    if (!trimmed) {
      setContactError(`Harap masukkan ${type === 'phone' ? 'nomor WhatsApp' : 'email'} yang valid.`);
      return;
    }

    if (type === 'phone' && trimmed === user?.phone && user?.phone_verified) {
      setContactError('Nomor WhatsApp yang Anda masukkan sama dengan nomor Anda saat ini.');
      return;
    }

    if (type === 'email' && trimmed.toLowerCase() === user?.email?.toLowerCase() && user?.email_verified) {
      setContactError('Alamat email yang Anda masukkan sama dengan email Anda saat ini.');
      return;
    }

    setContactType(type);
    setActiveContactTarget(trimmed);
    setAddingContact(true);
    setContactError('');

    try {
      const res = await fetch(`${API_BASE_URL}/auth/customer/add-contact`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          type,
          target: trimmed,
        }),
      });

      const json = await res.json();
      if (!res.ok) throw new Error(json.message || 'Gagal mengirim OTP untuk kontak baru.');

      setShowOtpModal(true);
    } catch (err: any) {
      setContactError(err.message);
    } finally {
      setAddingContact(false);
    }
  };

  const handleContactOtpVerified = async (data: any) => {
    setShowOtpModal(false);
    setPhoneInput('');
    setEmailInput('');
    setEditingPhone(false);
    setEditingEmail(false);
    setContactError('');

    if (data?.token && data?.customer) {
      login(data.token, data.customer);
    }
    await refreshProfile();
    alert('Kontak berhasil diverifikasi dan diperbarui di akun Anda!');
  };

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError('');
    setPasswordSuccess('');

    if (newPassword.length < 8) {
      setPasswordError('Password baru minimal harus 8 karakter.');
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError('Konfirmasi password baru tidak cocok.');
      return;
    }

    setPasswordLoading(true);

    try {
      const res = await fetch(`${API_BASE_URL}/auth/customer/change-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          current_password: currentPassword,
          new_password: newPassword,
          new_password_confirmation: confirmPassword,
        }),
      });

      const json = await res.json();
      if (!res.ok) {
        throw new Error(json.message || 'Gagal mengubah password.');
      }

      setPasswordSuccess('Password Anda berhasil diperbarui!');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setTimeout(() => setPasswordSuccess(''), 5000);
    } catch (err: any) {
      setPasswordError(err.message || 'Terjadi kesalahan saat mengubah password.');
    } finally {
      setPasswordLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header Profile */}
      <div className="bg-white rounded-3xl border border-slate-200 p-6 sm:p-8 shadow-sm">
        <div className="flex items-center space-x-4 mb-6">
          <div className="w-16 h-16 rounded-2xl bg-brand-600 text-white font-black text-2xl flex items-center justify-center shadow-md">
            {user.name.charAt(0).toUpperCase()}
          </div>
          <div>
            <h2 className="text-xl font-bold text-slate-900">{user.name}</h2>
            <p className="text-xs text-slate-500 flex items-center space-x-1 mt-0.5">
              <ShieldCheck className="w-4 h-4 text-emerald-600" />
              <span>Akun Pelanggan Apotek Santosa Farma</span>
            </p>
          </div>
        </div>

        {/* Name Form */}
        <form onSubmit={handleUpdateName} className="space-y-4 pt-4 border-t border-slate-100">
          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1.5">Nama Lengkap</label>
            <div className="flex items-center space-x-3">
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="flex-1 px-4 py-2.5 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium"
              />
              <button
                type="submit"
                disabled={updatingName || name === user.name}
                className="px-4 py-2.5 bg-slate-900 hover:bg-slate-800 disabled:opacity-40 text-white font-bold text-xs rounded-xl transition flex items-center space-x-1.5 shadow-sm"
              >
                <Save className="w-3.5 h-3.5" />
                <span>{updatingName ? 'Menyimpan...' : 'Simpan'}</span>
              </button>
            </div>
          </div>
          {nameSuccess && (
            <p className="text-xs font-bold text-emerald-600 flex items-center space-x-1 animate-fade-in">
              <CheckCircle className="w-3.5 h-3.5" />
              <span>Nama berhasil diperbarui!</span>
            </p>
          )}
        </form>
      </div>

      {/* Verified Contacts Management */}
      <div className="bg-white rounded-3xl border border-slate-200 p-6 sm:p-8 shadow-sm space-y-6">
        <div>
          <h3 className="text-base font-bold text-slate-900">Kontak & Keamanan Akun</h3>
          <p className="text-xs text-slate-500 mt-1">
            Anda dapat menggunakan No. WhatsApp atau Email yang sudah terverifikasi untuk login.
          </p>
        </div>

        {contactError && (
          <div className="p-3 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-xl flex items-center space-x-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{contactError}</span>
          </div>
        )}

        {/* WhatsApp Contact */}
        <div className="space-y-3">
          <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200/80 flex items-center justify-between flex-wrap gap-3">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-100 text-emerald-700 flex items-center justify-center flex-shrink-0">
                <Smartphone className="w-5 h-5" />
              </div>
              <div>
                <span className="text-[11px] font-bold text-slate-500 block">Nomor WhatsApp</span>
                <span className="text-sm font-extrabold text-slate-900">
                  {user.phone || 'Belum ditambahkan'}
                </span>
              </div>
            </div>

            <div className="flex items-center space-x-2">
              {user.phone && user.phone_verified ? (
                <span className="inline-flex items-center space-x-1 px-3 py-1 bg-emerald-100 text-emerald-800 rounded-full text-xs font-bold border border-emerald-200">
                  <CheckCircle className="w-3.5 h-3.5" />
                  <span>Terverifikasi</span>
                </span>
              ) : user.phone ? (
                <span className="inline-flex items-center space-x-1 px-3 py-1 bg-amber-100 text-amber-800 rounded-full text-xs font-bold border border-amber-200">
                  <span>Belum Verifikasi</span>
                </span>
              ) : null}

              {user.phone && (
                <button
                  type="button"
                  onClick={() => {
                    setEditingPhone(!editingPhone);
                    setPhoneInput('');
                    setContactError('');
                  }}
                  className="inline-flex items-center space-x-1 px-3 py-1 bg-white hover:bg-slate-100 text-slate-700 font-bold text-xs rounded-xl border border-slate-200 transition shadow-sm"
                >
                  <Edit3 className="w-3 h-3 text-slate-500" />
                  <span>{editingPhone ? 'Batal' : 'Ubah'}</span>
                </button>
              )}
            </div>
          </div>

          {/* Edit WhatsApp Form */}
          {editingPhone && (
            <div className="p-4 bg-brand-50/50 rounded-2xl border border-brand-200 space-y-3 animate-fade-in">
              <div className="flex items-center justify-between">
                <label className="block text-xs font-bold text-slate-800">
                  Ganti Nomor WhatsApp Baru (Wajib Verifikasi OTP)
                </label>
                <button
                  type="button"
                  onClick={() => {
                    setEditingPhone(false);
                    setPhoneInput('');
                  }}
                  className="text-slate-400 hover:text-slate-600 p-1"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="flex items-center space-x-2">
                <input
                  type="tel"
                  value={phoneInput}
                  onChange={(e) => setPhoneInput(e.target.value)}
                  placeholder="081234567890 (Nomor baru)"
                  className="flex-1 px-3 py-2 text-sm bg-white border border-slate-300 rounded-xl focus:border-brand-500 outline-none"
                />
                <button
                  type="button"
                  onClick={() => handleRequestChangeContact('phone', phoneInput)}
                  disabled={addingContact || !phoneInput.trim()}
                  className="px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-sm transition whitespace-nowrap"
                >
                  {addingContact ? 'Mengirim...' : 'Kirim OTP'}
                </button>
              </div>
            </div>
          )}

          {/* Add Phone if not present */}
          {!user.phone && (
            <div className="p-4 bg-brand-50/50 rounded-2xl border border-brand-200 space-y-3">
              <label className="block text-xs font-bold text-slate-800">
                + Hubungkan Nomor WhatsApp (Wajib Verifikasi OTP)
              </label>
              <div className="flex items-center space-x-2">
                <input
                  type="tel"
                  value={phoneInput}
                  onChange={(e) => setPhoneInput(e.target.value)}
                  placeholder="081234567890"
                  className="flex-1 px-3 py-2 text-sm bg-white border border-slate-300 rounded-xl focus:border-brand-500 outline-none"
                />
                <button
                  type="button"
                  onClick={() => handleRequestChangeContact('phone', phoneInput)}
                  disabled={addingContact || !phoneInput.trim()}
                  className="px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-sm transition whitespace-nowrap"
                >
                  {addingContact ? 'Mengirim...' : 'Kirim OTP'}
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Email Contact */}
        <div className="space-y-3">
          <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200/80 flex items-center justify-between flex-wrap gap-3">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center flex-shrink-0">
                <Mail className="w-5 h-5" />
              </div>
              <div>
                <span className="text-[11px] font-bold text-slate-500 block">Alamat Email</span>
                <span className="text-sm font-extrabold text-slate-900">
                  {user.email || 'Belum ditambahkan'}
                </span>
              </div>
            </div>

            <div className="flex items-center space-x-2">
              {user.email && user.email_verified ? (
                <span className="inline-flex items-center space-x-1 px-3 py-1 bg-emerald-100 text-emerald-800 rounded-full text-xs font-bold border border-emerald-200">
                  <CheckCircle className="w-3.5 h-3.5" />
                  <span>Terverifikasi</span>
                </span>
              ) : user.email ? (
                <span className="inline-flex items-center space-x-1 px-3 py-1 bg-amber-100 text-amber-800 rounded-full text-xs font-bold border border-amber-200">
                  <span>Belum Verifikasi</span>
                </span>
              ) : null}

              {user.email && (
                <button
                  type="button"
                  onClick={() => {
                    setEditingEmail(!editingEmail);
                    setEmailInput('');
                    setContactError('');
                  }}
                  className="inline-flex items-center space-x-1 px-3 py-1 bg-white hover:bg-slate-100 text-slate-700 font-bold text-xs rounded-xl border border-slate-200 transition shadow-sm"
                >
                  <Edit3 className="w-3 h-3 text-slate-500" />
                  <span>{editingEmail ? 'Batal' : 'Ubah'}</span>
                </button>
              )}
            </div>
          </div>

          {/* Edit Email Form */}
          {editingEmail && (
            <div className="p-4 bg-brand-50/50 rounded-2xl border border-brand-200 space-y-3 animate-fade-in">
              <div className="flex items-center justify-between">
                <label className="block text-xs font-bold text-slate-800">
                  Ganti Alamat Email Baru (Wajib Verifikasi OTP)
                </label>
                <button
                  type="button"
                  onClick={() => {
                    setEditingEmail(false);
                    setEmailInput('');
                  }}
                  className="text-slate-400 hover:text-slate-600 p-1"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="flex items-center space-x-2">
                <input
                  type="email"
                  value={emailInput}
                  onChange={(e) => setEmailInput(e.target.value)}
                  placeholder="nama@domain.com (Email baru)"
                  className="flex-1 px-3 py-2 text-sm bg-white border border-slate-300 rounded-xl focus:border-brand-500 outline-none"
                />
                <button
                  type="button"
                  onClick={() => handleRequestChangeContact('email', emailInput)}
                  disabled={addingContact || !emailInput.trim()}
                  className="px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-sm transition whitespace-nowrap"
                >
                  {addingContact ? 'Mengirim...' : 'Kirim OTP'}
                </button>
              </div>
            </div>
          )}

          {/* Add Email if not present */}
          {!user.email && (
            <div className="p-4 bg-brand-50/50 rounded-2xl border border-brand-200 space-y-3">
              <label className="block text-xs font-bold text-slate-800">
                + Hubungkan Alamat Email (Wajib Verifikasi OTP)
              </label>
              <div className="flex items-center space-x-2">
                <input
                  type="email"
                  value={emailInput}
                  onChange={(e) => setEmailInput(e.target.value)}
                  placeholder="nama@domain.com"
                  className="flex-1 px-3 py-2 text-sm bg-white border border-slate-300 rounded-xl focus:border-brand-500 outline-none"
                />
                <button
                  type="button"
                  onClick={() => handleRequestChangeContact('email', emailInput)}
                  disabled={addingContact || !emailInput.trim()}
                  className="px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-sm transition whitespace-nowrap"
                >
                  {addingContact ? 'Mengirim...' : 'Kirim OTP'}
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Change Password Card */}
      <div className="bg-white rounded-3xl border border-slate-200 p-6 sm:p-8 shadow-sm space-y-6">
        <div>
          <div className="flex items-center space-x-2.5 mb-1">
            <div className="w-8 h-8 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center">
              <Lock className="w-4 h-4" />
            </div>
            <h3 className="text-base font-bold text-slate-900">Ganti Password</h3>
          </div>
          <p className="text-xs text-slate-500">
            Perbarui kata sandi akun Anda secara berkala untuk menjaga keamanan.
          </p>
        </div>

        {passwordError && (
          <div className="p-3 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-xl flex items-center space-x-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{passwordError}</span>
          </div>
        )}

        {passwordSuccess && (
          <div className="p-3 bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs font-semibold rounded-xl flex items-center space-x-2 animate-fade-in">
            <CheckCircle className="w-4 h-4 flex-shrink-0" />
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
                className="w-full px-4 py-2.5 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium pr-10"
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

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Password Baru (Min. 8 Karakter)
              </label>
              <div className="relative">
                <input
                  type={showNewPassword ? 'text' : 'password'}
                  required
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Password baru"
                  className="w-full px-4 py-2.5 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium pr-10"
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
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="Ulangi password baru"
                  className="w-full px-4 py-2.5 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition font-medium pr-10"
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
          </div>

          <div className="pt-2 flex justify-end">
            <button
              type="submit"
              disabled={passwordLoading || !currentPassword || !newPassword || !confirmPassword}
              className="px-6 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-40 text-white font-bold text-xs rounded-xl transition flex items-center space-x-1.5 shadow-sm shadow-brand-600/20"
            >
              <Lock className="w-3.5 h-3.5" />
              <span>{passwordLoading ? 'Menyimpan...' : 'Perbarui Password'}</span>
            </button>
          </div>
        </form>
      </div>

      <OtpModal
        isOpen={showOtpModal}
        onClose={() => setShowOtpModal(false)}
        target={activeContactTarget}
        type={contactType}
        authToken={token}
        onSuccess={handleContactOtpVerified}
      />
    </div>
  );
}
