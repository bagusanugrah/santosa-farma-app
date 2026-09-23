'use client';

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { useStaffAuth } from '@/context/StaffAuthContext';
import { API_BASE_URL, Transaction, MetaPagination } from '@/lib/api';
import ReceiptModal from '@/components/ReceiptModal';
import {
  Receipt,
  Search,
  Printer,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  Calendar,
  AlertTriangle,
  WifiOff,
  LogIn,
} from 'lucide-react';

const MAX_RETRIES = 3;
const REQUEST_TIMEOUT_MS = 8000;

export default function AdminTransactionsPage() {
  const router = useRouter();
  const { user, token, loading: authLoading, logout } = useStaffAuth();

  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [meta, setMeta] = useState<MetaPagination>({
    current_page: 1,
    per_page: 10,
    total: 0,
    last_page: 1,
    from: null,
    to: null,
  });

  const [search, setSearch] = useState('');
  const [channelFilter, setChannelFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [perPage, setPerPage] = useState(10);
  const [page, setPage] = useState(1);

  // Loading & error handling states
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retryAttempt, setRetryAttempt] = useState(0);
  const [isRetrying, setIsRetrying] = useState(false);

  const [selectedTrx, setSelectedTrx] = useState<Transaction | null>(null);
  const [showReceiptModal, setShowReceiptModal] = useState(false);

  const retryTimerRef = useRef<NodeJS.Timeout | null>(null);
  const abortControllerRef = useRef<AbortController | null>(null);

  const fetchTransactions = useCallback(
    async (manual = false, attempt = 0) => {
      if (retryTimerRef.current) {
        clearTimeout(retryTimerRef.current);
        retryTimerRef.current = null;
      }
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }

      setLoading(true);
      if (manual) {
        setError(null);
        setRetryAttempt(0);
        setIsRetrying(false);
      }

      if (!token) {
        setError('Sesi admin tidak valid atau telah berakhir. Harap login kembali.');
        setLoading(false);
        return;
      }

      const controller = new AbortController();
      abortControllerRef.current = controller;
      const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

      try {
        const query = new URLSearchParams();
        if (search) query.append('search', search);
        if (channelFilter !== 'all') query.append('channel', channelFilter);
        if (statusFilter !== 'all') query.append('status', statusFilter);
        if (startDate) query.append('start_date', startDate);
        if (endDate) query.append('end_date', endDate);
        query.append('per_page', perPage.toString());
        query.append('page', page.toString());

        const res = await fetch(`${API_BASE_URL}/transactions?${query.toString()}`, {
          signal: controller.signal,
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/json',
          },
        });

        clearTimeout(timeoutId);

        if (res.status === 401) {
          setError('Sesi login telah kadaluarsa. Silakan lakukan login ulang.');
          setIsRetrying(false);
          setLoading(false);
          return;
        }

        if (!res.ok) {
          throw new Error(`Server merespon dengan status error ${res.status}`);
        }

        const json = await res.json();
        setTransactions(json.data || []);
        if (json.meta) {
          setMeta(json.meta);
        }
        setError(null);
        setRetryAttempt(0);
        setIsRetrying(false);
      } catch (err: any) {
        clearTimeout(timeoutId);
        const isAbort = err.name === 'AbortError';
        const msg = isAbort
          ? 'Koneksi ke server timeout (lebih dari 8 detik).'
          : err.message || 'Gagal memuat data transaksi dari server.';

        if (attempt < MAX_RETRIES) {
          setIsRetrying(true);
          const nextAttempt = attempt + 1;
          setRetryAttempt(nextAttempt);
          setError(`${msg} Mencoba menyambung kembali (${nextAttempt}/${MAX_RETRIES})...`);

          retryTimerRef.current = setTimeout(() => {
            fetchTransactions(false, nextAttempt);
          }, 2000);
        } else {
          setIsRetrying(false);
          setError(`${msg} Harap periksa koneksi backend atau klik tombol "Coba Lagi Sekarang".`);
        }
      } finally {
        setLoading(false);
      }
    },
    [search, channelFilter, statusFilter, startDate, endDate, perPage, page, token]
  );

  useEffect(() => {
    return () => {
      if (retryTimerRef.current) clearTimeout(retryTimerRef.current);
      if (abortControllerRef.current) abortControllerRef.current.abort();
    };
  }, []);

  useEffect(() => {
    if (authLoading) return;

    if (!token || !user) {
      router.push('/login');
      return;
    }
    if (user && user.role !== 'super_admin') {
      router.push('/pos');
      return;
    }
    fetchTransactions();
  }, [user, token, authLoading, fetchTransactions, router]);

  if (authLoading) {
    return (
      <div className="flex-1 p-8 flex flex-col items-center justify-center space-y-3">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xs text-slate-500 font-medium">Memeriksa sesi login admin...</p>
      </div>
    );
  }

  return (
    <div className="flex-1 p-8 space-y-6 overflow-y-auto">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-extrabold text-slate-900 flex items-center space-x-2">
            <Receipt className="w-6 h-6 text-brand-600" />
            <span>Semua Transaksi (Toko & Online)</span>
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Monitoring seluruh transaksi kasir toko fisik dan pesanan online web katalog
          </p>
        </div>

        <button
          onClick={() => fetchTransactions(true, 0)}
          disabled={loading || isRetrying}
          className="px-3.5 py-2 bg-white border border-slate-200 hover:bg-slate-50 disabled:opacity-50 text-slate-700 font-bold text-xs rounded-xl shadow-sm flex items-center space-x-1.5 transition"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>{loading ? 'Memuat...' : 'Refresh'}</span>
        </button>
      </div>

      {/* Top Banner if error happens while transactions already exist */}
      {error && transactions.length > 0 && (
        <div className="p-3 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-2xl flex items-center justify-between shadow-sm animate-fade-in">
          <div className="flex items-center space-x-2">
            {isRetrying ? (
              <RefreshCw className="w-4 h-4 text-amber-600 animate-spin flex-shrink-0" />
            ) : (
              <AlertTriangle className="w-4 h-4 text-red-600 flex-shrink-0" />
            )}
            <span>{error}</span>
          </div>
          <button
            onClick={() => fetchTransactions(true, 0)}
            className="px-3 py-1 bg-red-600 hover:bg-red-700 text-white rounded-lg text-xs font-bold transition flex-shrink-0 ml-3"
          >
            Coba Lagi
          </button>
        </div>
      )}

      {/* Filters Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
            placeholder="Cari invoice atau pelanggan..."
            className="w-full pl-9 pr-3 py-1.5 text-xs bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none"
          />
        </div>

        <div className="flex items-center space-x-2.5 flex-wrap gap-y-2">
          <select
            value={channelFilter}
            onChange={(e) => {
              setChannelFilter(e.target.value);
              setPage(1);
            }}
            className="bg-slate-50 border border-slate-200 rounded-xl px-2.5 py-1.5 text-slate-700 text-xs font-medium outline-none"
          >
            <option value="all">Semua Channel</option>
            <option value="toko">Toko Kasir</option>
            <option value="online">Online Web</option>
          </select>

          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPage(1);
            }}
            className="bg-slate-50 border border-slate-200 rounded-xl px-2.5 py-1.5 text-slate-700 text-xs font-medium outline-none"
          >
            <option value="all">Semua Status</option>
            <option value="selesai">Selesai</option>
            <option value="paid">Paid</option>
            <option value="diambil">Diambil</option>
            <option value="pending">Pending</option>
            <option value="expired">Expired</option>
          </select>

          <div className="flex items-center space-x-1.5 bg-slate-50 border border-slate-200 rounded-xl px-2.5 py-1">
            <Calendar className="w-3.5 h-3.5 text-slate-400" />
            <input
              type="date"
              value={startDate}
              onChange={(e) => {
                setStartDate(e.target.value);
                setPage(1);
              }}
              className="bg-transparent text-slate-700 text-xs outline-none"
            />
            <span className="text-slate-400 text-xs">-</span>
            <input
              type="date"
              value={endDate}
              onChange={(e) => {
                setEndDate(e.target.value);
                setPage(1);
              }}
              className="bg-transparent text-slate-700 text-xs outline-none"
            />
          </div>

          <div className="flex items-center space-x-1 border-l border-slate-200 pl-2.5">
            <span className="text-slate-500 font-medium text-xs">Tampil:</span>
            <select
              value={perPage}
              onChange={(e) => {
                setPerPage(Number(e.target.value));
                setPage(1);
              }}
              className="bg-slate-50 border border-slate-200 rounded-xl px-2 py-1.5 text-slate-800 font-bold outline-none text-xs"
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 font-bold">
            <tr>
              <th className="py-3.5 px-4">No. Invoice</th>
              <th className="py-3.5 px-4">Waktu</th>
              <th className="py-3.5 px-4">Channel</th>
              <th className="py-3.5 px-4">Metode</th>
              <th className="py-3.5 px-4">Pihak Terkait</th>
              <th className="py-3.5 px-4 text-right">Total Transaksi</th>
              <th className="py-3.5 px-4 text-center">Status</th>
              <th className="py-3.5 px-4 text-center">Struk</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {loading && transactions.length === 0 ? (
              <tr>
                <td colSpan={8} className="text-center py-12 text-slate-400">
                  <div className="flex flex-col items-center justify-center space-y-3">
                    <div className="w-7 h-7 border-3 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
                    <p className="text-xs font-medium text-slate-600">
                      {isRetrying
                        ? `Mencoba menghubungkan kembali (${retryAttempt}/${MAX_RETRIES})...`
                        : 'Memuat data transaksi...'}
                    </p>
                  </div>
                </td>
              </tr>
            ) : error && transactions.length === 0 ? (
              <tr>
                <td colSpan={8} className="py-12 px-4 text-center">
                  <div className="max-w-md mx-auto flex flex-col items-center space-y-3">
                    <div className="w-12 h-12 rounded-2xl bg-red-50 text-red-600 flex items-center justify-center shadow-inner">
                      <WifiOff className="w-6 h-6" />
                    </div>
                    <div>
                      <h4 className="text-sm font-extrabold text-slate-900">Gagal Memuat Data Transaksi</h4>
                      <p className="text-xs text-slate-500 mt-1 max-w-sm leading-relaxed">{error}</p>
                    </div>
                    {isRetrying ? (
                      <div className="flex items-center space-x-2 text-xs font-semibold text-brand-600 pt-1">
                        <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                        <span>Mencoba kembali secara otomatis...</span>
                      </div>
                    ) : (
                      <div className="flex items-center space-x-2 pt-2">
                        <button
                          type="button"
                          onClick={() => fetchTransactions(true, 0)}
                          className="px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white text-xs font-bold rounded-xl shadow-md transition flex items-center space-x-1.5"
                        >
                          <RefreshCw className="w-3.5 h-3.5" />
                          <span>Coba Lagi Sekarang</span>
                        </button>
                        {error.includes('login') && (
                          <button
                            type="button"
                            onClick={() => {
                              logout();
                              router.push('/login');
                            }}
                            className="px-4 py-2 bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold rounded-xl transition flex items-center space-x-1.5"
                          >
                            <LogIn className="w-3.5 h-3.5" />
                            <span>Login Ulang</span>
                          </button>
                        )}
                      </div>
                    )}
                  </div>
                </td>
              </tr>
            ) : transactions.length === 0 ? (
              <tr>
                <td colSpan={8} className="text-center py-10 text-slate-400 text-xs font-medium">
                  Tidak ada data transaksi ditemukan.
                </td>
              </tr>
            ) : (
              transactions.map((trx) => (
                <tr key={trx.id} className="hover:bg-slate-50/80 transition">
                  <td className="py-3 px-4 font-bold text-slate-900">{trx.invoice_no}</td>
                  <td className="py-3 px-4 text-slate-500">
                    {new Date(trx.created_at).toLocaleDateString('id-ID', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </td>
                  <td className="py-3 px-4">
                    <span
                      className={`px-2 py-0.5 rounded-md font-bold text-[10px] uppercase ${
                        trx.channel === 'toko' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'
                      }`}
                    >
                      {trx.channel}
                    </span>
                  </td>
                  <td className="py-3 px-4 font-bold text-slate-700 uppercase">{trx.payment_method}</td>
                  <td className="py-3 px-4 text-slate-600">
                    {trx.channel === 'toko' ? (
                      <span>Kasir: {trx.cashier?.name || '-'}</span>
                    ) : (
                      <span>{trx.customer?.name || 'Online'}</span>
                    )}
                  </td>
                  <td className="py-3 px-4 text-right font-extrabold text-slate-900">
                    Rp {trx.total.toLocaleString('id-ID')}
                  </td>
                  <td className="py-3 px-4 text-center">
                    <span
                      className={`px-2.5 py-0.5 rounded-full font-bold text-[10px] uppercase ${
                        ['selesai', 'paid', 'diambil'].includes(trx.status)
                          ? 'bg-emerald-100 text-emerald-800'
                          : trx.status === 'pending'
                          ? 'bg-amber-100 text-amber-800'
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {trx.status}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-center">
                    <button
                      onClick={() => {
                        setSelectedTrx(trx);
                        setShowReceiptModal(true);
                      }}
                      className="p-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg transition"
                      title="Cetak Ulang Struk"
                    >
                      <Printer className="w-3.5 h-3.5" />
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>

        {/* Pagination Bar */}
        {meta.total > 0 && (
          <div className="bg-slate-50 px-4 py-3 border-t border-slate-200 flex items-center justify-between text-xs text-slate-600">
            <div>
              Menampilkan <strong>{meta.from ?? 0}</strong> - <strong>{meta.to ?? 0}</strong> dari{' '}
              <strong>{meta.total}</strong> transaksi
            </div>

            <div className="flex items-center space-x-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
                className="p-1.5 bg-white border border-slate-200 rounded-lg hover:bg-slate-100 disabled:opacity-40"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <span className="font-bold">
                {meta.current_page} / {meta.last_page}
              </span>
              <button
                onClick={() => setPage((p) => Math.min(meta.last_page, p + 1))}
                disabled={page >= meta.last_page}
                className="p-1.5 bg-white border border-slate-200 rounded-lg hover:bg-slate-100 disabled:opacity-40"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>

      <ReceiptModal
        isOpen={showReceiptModal}
        onClose={() => setShowReceiptModal(false)}
        transaction={selectedTrx}
      />
    </div>
  );
}
