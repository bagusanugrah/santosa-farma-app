'use client';

import React, { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { API_BASE_URL, Transaction } from '@/lib/api';
import { supabase } from '@/lib/supabase';
import { loadSnapScript } from '@/lib/midtrans';
import QrPickupModal from '@/components/QrPickupModal';
import {
  Package,
  QrCode,
  RefreshCw,
  ShoppingBag,
  Trash2,
  CreditCard,
  Copy,
  Check,
  AlertCircle,
} from 'lucide-react';

export default function MyOrdersPage() {
  const router = useRouter();
  const { user, token, loading: authLoading } = useAuth();

  const [orders, setOrders] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [verifyingInvoice, setVerifyingInvoice] = useState<string | null>(null);
  const [cancellingInvoice, setCancellingInvoice] = useState<string | null>(null);
  const [payingInvoice, setPayingInvoice] = useState<string | null>(null);
  const [copiedVa, setCopiedVa] = useState<string | null>(null);
  const [paymentDetailsMap, setPaymentDetailsMap] = useState<Record<string, any>>({});
  const [activeTab, setActiveTab] = useState<'all' | 'pending' | 'paid' | 'diambil'>('all');
  const [selectedTrx, setSelectedTrx] = useState<Transaction | null>(null);
  const [showQrModal, setShowQrModal] = useState(false);

  const fetchOrders = useCallback(async () => {
    if (!user) return;
    try {
      // 1. Direct Supabase query first (always live & fresh, bypasses Vercel API/Data Cache)
      const { data: directData, error: directErr } = await supabase
        .from('transactions')
        .select('*, items:transaction_items(*)')
        .eq('customer_id', user.id)
        .not('status', 'in', '("dibatalkan","expired","gagal")')
        .order('id', { ascending: false });

      if (!directErr && directData && directData.length > 0) {
        setOrders(directData as any);
        loadPendingPaymentDetails(directData as any);
        return;
      }

      // 2. Fallback / server sync via API route when authenticated
      if (token) {
        const res = await fetch(`${API_BASE_URL}/transactions/customer/my-orders?_t=${Date.now()}`, {
          cache: 'no-store',
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/json',
          },
        });
        if (res.ok) {
          const json = await res.json();
          const list = json.data || [];
          setOrders(list);
          loadPendingPaymentDetails(list);
          return;
        }
      }

      if (directData) {
        setOrders(directData as any);
        loadPendingPaymentDetails(directData as any);
      }
    } catch (err) {
      console.error('Error fetching orders', err);
    } finally {
      setLoading(false);
    }
  }, [user, token]);

  const loadPendingPaymentDetails = useCallback(
    async (list: Transaction[]) => {
      if (!token) return;
      const pendingOnline = list.filter(
        (o) =>
          o.status === 'pending' &&
          o.payment_method !== 'pharmacy' &&
          o.payment_method !== 'bayar_di_apotek'
      );
      let needsRefresh = false;
      for (const o of pendingOnline) {
        try {
          const res = await fetch(`${API_BASE_URL}/transactions/customer/pay-order`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Accept: 'application/json',
              Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify({ invoice_no: o.invoice_no }),
          });
          if (res.ok) {
            const json = await res.json();
            if (json.data?.payment_details) {
              setPaymentDetailsMap((prev) => ({
                ...prev,
                [o.invoice_no]: json.data.payment_details,
              }));
            }
            if (json.data?.is_paid || json.data?.is_expired || json.data?.deleted) {
              needsRefresh = true;
            }
          }
        } catch (_) {}
      }
      if (needsRefresh) {
        fetchOrders();
      }
    },
    [token]
  );

  useEffect(() => {
    if (authLoading) return;

    if (!token || !user) {
      router.replace('/login?redirect=/orders');
      return;
    }

    fetchOrders();

    // Supabase Realtime Subscription: auto-sync orders when cashier processes or cancels
    const channel = supabase
      .channel(`public:transactions:customer:${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'transactions',
        },
        () => {
          fetchOrders();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user, token, authLoading, router, fetchOrders]);

  const handleVerifyPayment = async (invoiceNo: string) => {
    if (!token) return;
    setVerifyingInvoice(invoiceNo);
    try {
      const res = await fetch(`${API_BASE_URL}/transactions/verify-payment`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ invoice_no: invoiceNo }),
      });
      if (res.ok) {
        const json = await res.json();
        if (json.deleted || json.is_expired) {
          alert(json.message || 'Batas waktu pembayaran telah berakhir. Pesanan otomatis dibatalkan dan dihapus.');
        }
        await fetchOrders();
      }
    } catch (err) {
      console.error('Error verifying payment:', err);
    } finally {
      setVerifyingInvoice(null);
    }
  };

  const handleCancelOrder = async (invoiceNo: string) => {
    if (!token) return;
    if (!window.confirm(`Yakin ingin membatalkan pesanan ${invoiceNo}? Pesanan akan dihapus.`)) return;

    setCancellingInvoice(invoiceNo);
    try {
      const res = await fetch(`${API_BASE_URL}/transactions/customer/cancel-order`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ invoice_no: invoiceNo }),
      });
      if (res.ok) {
        await fetchOrders();
      } else {
        const json = await res.json();
        alert(json.message || 'Gagal membatalkan pesanan.');
      }
    } catch (err) {
      console.error('Error cancelling order:', err);
    } finally {
      setCancellingInvoice(null);
    }
  };

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedVa(id);
    setTimeout(() => {
      setCopiedVa(null);
    }, 2000);
  };

  const handlePayOnline = async (order: Transaction) => {
    if (!token) return;
    setPayingInvoice(order.invoice_no);
    try {
      const res = await fetch(`${API_BASE_URL}/transactions/customer/pay-order`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ invoice_no: order.invoice_no }),
      });

      const json = await res.json();
      if (!res.ok) {
        alert(json.message || 'Gagal memuat pembayaran.');
        return;
      }

      const data = json.data;
      if (data.is_expired || data.deleted) {
        alert('Batas waktu pembayaran telah berakhir. Pesanan otomatis dibatalkan dan dihapus.');
        await fetchOrders();
        return;
      }

      if (data.is_paid) {
        alert('Pembayaran pesanan ini sudah berhasil dikonfirmasi!');
        await fetchOrders();
        return;
      }

      if (data.payment_details) {
        setPaymentDetailsMap((prev) => ({
          ...prev,
          [order.invoice_no]: data.payment_details,
        }));
      }

      const snapToken = data.snap_token;
      if (!snapToken) {
        alert('Gagal mendapatkan token pembayaran Midtrans.');
        return;
      }

      await loadSnapScript(data.client_key, data.is_production);

      if ((window as any).snap) {
        (window as any).snap.pay(snapToken, {
          onSuccess: async () => {
            await handleVerifyPayment(order.invoice_no);
            await fetchOrders();
          },
          onPending: async () => {
            await handleVerifyPayment(order.invoice_no);
            await fetchOrders();
          },
          onError: () => {
            alert('Pembayaran gagal atau dibatalkan.');
          },
          onClose: async () => {
            await handleVerifyPayment(order.invoice_no);
            await fetchOrders();
          },
        });
      } else {
        alert('Gagal memuat popup pembayaran Midtrans. Silakan coba sesaat lagi.');
      }
    } catch (err: any) {
      console.error('Error opening payment:', err);
      alert('Terjadi kesalahan: ' + (err.message || 'Gagal membuka pembayaran'));
    } finally {
      setPayingInvoice(null);
    }
  };

  if (authLoading) {
    return (
      <div className="max-w-4xl mx-auto py-16 flex flex-col items-center justify-center space-y-3">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xs text-slate-500 font-medium">Memuat pesanan...</p>
      </div>
    );
  }

  if (!user || !token) return null;

  const filteredOrders = orders.filter((order) => {
    if (['dibatalkan', 'expired', 'gagal'].includes(order.status)) return false;
    if (activeTab === 'all') return true;
    return order.status === activeTab;
  });

  const getStatusBadge = (order: any) => {
    switch (order.status) {
      case 'paid':
        return (
          <span className="px-3 py-1 bg-emerald-100 text-emerald-800 rounded-full text-xs font-bold border border-emerald-200">
            Siap Diambil di Toko
          </span>
        );
      case 'diambil':
        return (
          <span className="px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-xs font-bold border border-blue-200">
            Sudah Diambil
          </span>
        );
      case 'pending':
        return (
          <span className="px-3 py-1 bg-amber-100 text-amber-800 rounded-full text-xs font-bold border border-amber-200">
            {order.payment_method === 'pharmacy' || order.payment_method === 'bayar_di_apotek'
              ? 'Bayar di Kasir (Apotek)'
              : 'Menunggu Pembayaran'}
          </span>
        );
      default:
        return (
          <span className="px-3 py-1 bg-slate-100 text-slate-700 rounded-full text-xs font-bold">
            {order.status}
          </span>
        );
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-4 sm:space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <Package className="w-5 h-5 sm:w-6 sm:h-6 text-brand-600" />
          <h2 className="text-xl sm:text-2xl font-black text-slate-900">Pesanan Saya</h2>
        </div>
        <button
          onClick={() => fetchOrders()}
          disabled={loading}
          className="px-3 py-1.5 text-xs font-bold text-brand-600 hover:text-brand-700 bg-brand-50 hover:bg-brand-100 rounded-xl flex items-center space-x-1.5 transition"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>Muat Ulang</span>
        </button>
      </div>

      {/* Tabs */}
      <div className="flex items-center space-x-2 border-b border-slate-200 pb-2 overflow-x-auto scrollbar-none -mx-3.5 px-3.5 sm:mx-0 sm:px-0">
        {[
          { id: 'all', label: `Semua Pesanan (${orders.length})` },
          { id: 'paid', label: `Siap Diambil (${orders.filter((o) => o.status === 'paid').length})` },
          { id: 'pending', label: `Menunggu Bayar (${orders.filter((o) => o.status === 'pending').length})` },
          { id: 'diambil', label: `Selesai (${orders.filter((o) => o.status === 'diambil' || o.status === 'selesai').length})` },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`px-3.5 sm:px-4 py-2 rounded-xl text-xs font-bold transition whitespace-nowrap ${
              activeTab === tab.id
                ? 'bg-brand-600 text-white shadow-sm'
                : 'text-slate-600 hover:bg-slate-100'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Orders List */}
      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="bg-white rounded-2xl sm:rounded-3xl p-4 sm:p-6 border border-slate-200 animate-pulse space-y-3">
              <div className="h-4 bg-slate-100 rounded w-1/4" />
              <div className="h-10 bg-slate-100 rounded" />
              <div className="h-4 bg-slate-100 rounded w-1/3" />
            </div>
          ))}
        </div>
      ) : filteredOrders.length === 0 ? (
        <div className="bg-white rounded-2xl sm:rounded-3xl border border-slate-200 p-8 sm:p-12 text-center text-slate-400">
          <ShoppingBag className="w-12 h-12 mx-auto mb-3 text-slate-300" />
          <h4 className="font-bold text-slate-700">Belum ada transaksi di tab ini</h4>
          <p className="text-xs text-slate-400 mt-1">Pesanan online yang Anda buat akan tercatat di sini.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredOrders.map((order) => (
            <div
              key={order.id}
              className="bg-white rounded-2xl sm:rounded-3xl border border-slate-200 p-4 sm:p-6 shadow-sm hover:shadow-md transition space-y-4"
            >
              <div className="flex items-center justify-between flex-wrap gap-2 pb-3 border-b border-slate-100">
                <div>
                  <Link
                    href={`/orders/${order.invoice_no}`}
                    className="text-xs font-bold text-slate-900 hover:text-brand-600 transition block"
                  >
                    {order.invoice_no}
                  </Link>
                  <span className="text-[11px] text-slate-400">
                    {new Date(order.created_at).toLocaleDateString('id-ID', {
                      day: 'numeric',
                      month: 'long',
                      year: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </span>
                </div>
                <div>{getStatusBadge(order)}</div>
              </div>

              {/* Items */}
              <div className="space-y-2">
                {order.items?.map((item) => (
                  <div key={item.id} className="flex justify-between gap-3 text-xs">
                    <span className="text-slate-700 font-medium min-w-0 flex-1 break-words">
                      {item.qty}x {item.product_name}
                    </span>
                    <span className="font-bold text-slate-900 shrink-0">
                      Rp {Number(item.subtotal).toLocaleString('id-ID')}
                    </span>
                  </div>
                ))}
              </div>

              {/* Payment Details / Virtual Account Box for Pending Online Orders */}
              {order.status === 'pending' &&
                order.payment_method !== 'pharmacy' &&
                order.payment_method !== 'bayar_di_apotek' && (
                  <div className="bg-gradient-to-r from-amber-50/80 to-orange-50/80 border border-amber-200 rounded-2xl p-3.5 space-y-2.5">
                    <div className="flex items-center justify-between flex-wrap gap-1">
                      <div className="flex items-center space-x-1.5 text-xs font-extrabold text-amber-900">
                        <CreditCard className="w-4 h-4 text-amber-700" />
                        <span>
                          {paymentDetailsMap[order.invoice_no]?.bank_name
                            ? `Virtual Account ${paymentDetailsMap[order.invoice_no].bank_name}`
                            : paymentDetailsMap[order.invoice_no]?.qr_url
                            ? 'Pembayaran QRIS Midtrans'
                            : 'Pembayaran Online Midtrans'}
                        </span>
                      </div>
                      {paymentDetailsMap[order.invoice_no]?.expiry_time && (
                        <span className="text-[10px] font-bold text-amber-700 bg-amber-100 px-2 py-0.5 rounded-full">
                          Batas Bayar: {paymentDetailsMap[order.invoice_no].expiry_time}
                        </span>
                      )}
                    </div>

                    {paymentDetailsMap[order.invoice_no]?.va_number ? (
                      <div className="flex items-center justify-between gap-2 flex-wrap bg-white border border-amber-200 rounded-xl px-3 py-2">
                        <div className="min-w-0">
                          <span className="text-[10px] text-slate-400 block font-medium">Nomor Virtual Account</span>
                          <span className="text-sm sm:text-base font-black tracking-wider font-mono text-slate-900 break-all">
                            {paymentDetailsMap[order.invoice_no].va_number}
                          </span>
                        </div>
                        <button
                          onClick={() => copyToClipboard(paymentDetailsMap[order.invoice_no].va_number, order.invoice_no)}
                          className="px-2.5 py-1.5 bg-amber-50 hover:bg-amber-100 active:bg-amber-200 border border-amber-200 rounded-lg text-amber-900 text-xs font-bold transition flex items-center space-x-1 shrink-0"
                        >
                          {copiedVa === order.invoice_no ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                          <span>{copiedVa === order.invoice_no ? 'Tersalin' : 'Salin'}</span>
                        </button>
                      </div>
                    ) : paymentDetailsMap[order.invoice_no]?.bill_key ? (
                      <div className="bg-white border border-amber-200 rounded-xl p-2.5 text-xs space-y-1">
                        <div><span className="text-slate-400">Kode Perusahaan (Biller): </span><span className="font-mono font-bold text-slate-900">{paymentDetailsMap[order.invoice_no].biller_code}</span></div>
                        <div><span className="text-slate-400">Kode Pembayaran (Bill Key): </span><span className="font-mono font-bold text-slate-900">{paymentDetailsMap[order.invoice_no].bill_key}</span></div>
                      </div>
                    ) : paymentDetailsMap[order.invoice_no]?.qr_url ? (
                      <div className="bg-white border border-amber-200 rounded-xl p-3 flex flex-col sm:flex-row items-center gap-3">
                        <img
                          src={paymentDetailsMap[order.invoice_no].qr_url}
                          alt={`QRIS ${order.invoice_no}`}
                          className="w-28 h-28 object-contain rounded-lg border border-slate-100 bg-white flex-shrink-0"
                        />
                        <div className="text-xs text-amber-900 space-y-1 text-center sm:text-left">
                          <p className="font-bold">Scan QRIS di atas untuk menyelesaikan pembayaran.</p>
                          <p className="text-[11px] text-amber-700">
                            Setelah membayar, klik <strong>Cek Status Bayar</strong> atau buka kembali lewat tombol <strong>Bayar Sekarang</strong>.
                          </p>
                        </div>
                      </div>
                    ) : (
                      <div className="flex items-start space-x-2 text-xs text-amber-800">
                        <AlertCircle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                        <p>
                          Popup pembayaran sempat ditutup sebelum selesai. Klik tombol <strong>Bayar Sekarang</strong> di bawah untuk membuka kembali pilihan pembayaran (Bank BCA, Mandiri, BRI, QRIS, dll).
                        </p>
                      </div>
                    )}
                  </div>
                )}

              {/* Total & Action Buttons */}
              <div className="pt-3 border-t border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div className="flex sm:flex-col justify-between sm:justify-start items-center sm:items-start">
                  <span className="text-[11px] text-slate-400 block font-medium">Total Pembayaran</span>
                  <span className="text-base font-extrabold text-slate-900">
                    Rp {Number(order.total).toLocaleString('id-ID')}
                  </span>
                </div>

                <div className="flex items-center gap-2 w-full sm:w-auto flex-wrap sm:flex-nowrap">
                  {order.status === 'pending' && (order.payment_method === 'pharmacy' || order.payment_method === 'bayar_di_apotek') && (
                    <button
                      onClick={() => {
                        setSelectedTrx(order);
                        setShowQrModal(true);
                      }}
                      className="w-full sm:w-auto justify-center px-4 py-2.5 bg-brand-600 hover:bg-brand-700 text-white font-bold text-xs rounded-xl shadow-md flex items-center space-x-1.5 transition"
                    >
                      <QrCode className="w-4 h-4" />
                      <span>QR Pesanan Kasir</span>
                    </button>
                  )}

                  {order.status === 'pending' && order.payment_method !== 'pharmacy' && order.payment_method !== 'bayar_di_apotek' && (
                    <>
                      <button
                        onClick={() => handlePayOnline(order)}
                        disabled={payingInvoice === order.invoice_no}
                        className="w-full sm:w-auto justify-center px-4 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-md flex items-center space-x-1.5 transition"
                      >
                        {payingInvoice === order.invoice_no ? (
                          <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                        ) : (
                          <CreditCard className="w-3.5 h-3.5" />
                        )}
                        <span>
                          {payingInvoice === order.invoice_no
                            ? 'Membuka...'
                            : paymentDetailsMap[order.invoice_no]?.va_number
                            ? 'Buka Popup / Ganti Metode'
                            : 'Bayar Sekarang'}
                        </span>
                      </button>

                      <button
                        onClick={() => handleVerifyPayment(order.invoice_no)}
                        disabled={verifyingInvoice === order.invoice_no}
                        className="w-full sm:w-auto justify-center px-3.5 py-2.5 bg-amber-500 hover:bg-amber-600 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-sm flex items-center space-x-1.5 transition"
                      >
                        <RefreshCw
                          className={`w-3.5 h-3.5 ${verifyingInvoice === order.invoice_no ? 'animate-spin' : ''}`}
                        />
                        <span>
                          {verifyingInvoice === order.invoice_no ? 'Memeriksa...' : 'Cek Status Bayar'}
                        </span>
                      </button>
                    </>
                  )}

                  {order.status === 'pending' && (
                    <button
                      onClick={() => handleCancelOrder(order.invoice_no)}
                      disabled={cancellingInvoice === order.invoice_no}
                      className="w-full sm:w-auto justify-center px-3 py-2.5 border border-red-200 text-red-600 hover:bg-red-50 disabled:opacity-50 font-bold text-xs rounded-xl flex items-center space-x-1 transition"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                      <span>{cancellingInvoice === order.invoice_no ? 'Membatalkan...' : 'Batalkan'}</span>
                    </button>
                  )}

                  {order.status === 'paid' && (
                    <button
                      onClick={() => {
                        setSelectedTrx(order);
                        setShowQrModal(true);
                      }}
                      className="w-full sm:w-auto justify-center px-4 py-2.5 bg-brand-600 hover:bg-brand-700 text-white font-bold text-xs rounded-xl shadow-md flex items-center space-x-1.5 transition"
                    >
                      <QrCode className="w-4 h-4" />
                      <span>Lihat QR Pengambilan</span>
                    </button>
                  )}

                  {order.status === 'diambil' && (
                    <button
                      onClick={() => window.open(`${API_BASE_URL}/receipts/${order.id}/pdf`, '_blank')}
                      className="w-full sm:w-auto text-center px-3 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition"
                    >
                      Unduh Struk PDF
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <QrPickupModal
        isOpen={showQrModal}
        onClose={() => setShowQrModal(false)}
        transaction={selectedTrx}
      />
    </div>
  );
}

