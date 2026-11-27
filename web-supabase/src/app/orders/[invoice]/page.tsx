'use client';

import React, { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { API_BASE_URL, Transaction } from '@/lib/api';
import { supabase } from '@/lib/supabase';
import { loadSnapScript } from '@/lib/midtrans';
import { QRCodeSVG } from 'qrcode.react';
import {
  ArrowLeft,
  CheckCircle2,
  QrCode,
  FileText,
  CreditCard,
  Copy,
  Check,
  RefreshCw,
  AlertCircle,
  Trash2,
} from 'lucide-react';
import Link from 'next/link';

export default function OrderDetailPage() {
  const params = useParams();
  const router = useRouter();
  const { user, token, loading: authLoading } = useAuth();
  const invoiceNo = params.invoice as string;

  const [order, setOrder] = useState<Transaction | null>(null);
  const [loading, setLoading] = useState(true);
  const [paymentDetails, setPaymentDetails] = useState<any>(null);
  const [paying, setPaying] = useState(false);
  const [verifying, setVerifying] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [copiedVa, setCopiedVa] = useState(false);

  const fetchOrder = async () => {
    try {
      // 1. Direct Supabase query first so newly created orders are immediately visible
      const { data: directTrx, error: directErr } = await supabase
        .from('transactions')
        .select('*, items:transaction_items(*)')
        .eq('invoice_no', invoiceNo)
        .eq('customer_id', user?.id)
        .not('status', 'in', '("dibatalkan","expired","gagal")')
        .maybeSingle();

      if (!directErr && directTrx) {
        setOrder(directTrx as any);
        if (
          directTrx.status === 'pending' &&
          directTrx.payment_method !== 'pharmacy' &&
          directTrx.payment_method !== 'bayar_di_apotek'
        ) {
          fetchPaymentInfo();
        }
        return;
      }

      // 2. Fallback via authenticated server API
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
          const found = json.data.find((o: Transaction) => o.invoice_no === invoiceNo);
          setOrder(found || null);
          if (
            found &&
            found.status === 'pending' &&
            found.payment_method !== 'pharmacy' &&
            found.payment_method !== 'bayar_di_apotek'
          ) {
            fetchPaymentInfo();
          }
          return;
        }
      }

      setOrder(null);
    } catch (err) {
      console.error('Error fetching order detail', err);
    } finally {
      setLoading(false);
    }
  };

  const fetchPaymentInfo = async () => {
    if (!token || !invoiceNo) return;
    try {
      const res = await fetch(`${API_BASE_URL}/transactions/customer/pay-order`, {
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
        if (json.data?.is_expired || json.data?.deleted) {
          setOrder(null);
          return;
        }
        if (json.data?.payment_details) {
          setPaymentDetails(json.data.payment_details);
        }
        if (json.data?.is_paid) {
          fetchOrder();
        }
      }
    } catch (_) {}
  };

  useEffect(() => {
    if (authLoading) return;

    if (!token || !user) {
      router.replace(`/login?redirect=/orders/${invoiceNo}`);
      return;
    }

    fetchOrder();

    // Supabase Realtime Subscription
    const channel = supabase
      .channel(`public:transactions:detail:${invoiceNo}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'transactions',
          filter: `invoice_no=eq.${invoiceNo}`,
        },
        () => {
          fetchOrder();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user, token, authLoading, invoiceNo, router]);

  const handlePayOnline = async () => {
    if (!token || !order) return;
    setPaying(true);
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
        router.replace('/orders');
        return;
      }

      if (data.is_paid) {
        alert('Pembayaran pesanan ini sudah berhasil dikonfirmasi!');
        await fetchOrder();
        return;
      }

      if (data.payment_details) {
        setPaymentDetails(data.payment_details);
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
            await handleVerifyPayment();
            await fetchOrder();
          },
          onPending: async () => {
            await handleVerifyPayment();
            await fetchOrder();
          },
          onError: () => {
            alert('Pembayaran gagal atau dibatalkan.');
          },
          onClose: async () => {
            await handleVerifyPayment();
            await fetchOrder();
          },
        });
      } else {
        alert('Gagal memuat popup pembayaran Midtrans. Silakan coba sesaat lagi.');
      }
    } catch (err: any) {
      console.error('Error opening payment:', err);
      alert('Terjadi kesalahan: ' + (err.message || 'Gagal membuka pembayaran'));
    } finally {
      setPaying(false);
    }
  };

  const handleVerifyPayment = async () => {
    if (!token || !invoiceNo) return;
    setVerifying(true);
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
          alert(json.message || 'Batas waktu pembayaran telah berakhir. Pesanan otomatis dibatalkan.');
          router.replace('/orders');
          return;
        }
        await fetchOrder();
      }
    } catch (err) {
      console.error('Error verifying payment:', err);
    } finally {
      setVerifying(false);
    }
  };

  const handleCancelOrder = async () => {
    if (!token || !invoiceNo) return;
    if (!window.confirm(`Yakin ingin membatalkan pesanan ${invoiceNo}? Pesanan akan dihapus.`)) return;

    setCancelling(true);
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
        router.replace('/orders');
      } else {
        const json = await res.json();
        alert(json.message || 'Gagal membatalkan pesanan.');
      }
    } catch (err) {
      console.error('Error cancelling order:', err);
    } finally {
      setCancelling(false);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedVa(true);
    setTimeout(() => setCopiedVa(false), 2000);
  };

  if (authLoading || loading) {
    return (
      <div className="max-w-md mx-auto py-16 flex flex-col items-center justify-center space-y-3">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xs text-slate-500 font-medium">Memuat detail pesanan...</p>
      </div>
    );
  }

  if (!user || !token) return null;

  if (!order) {
    return (
      <div className="max-w-md mx-auto py-16 text-center">
        <p className="font-bold text-slate-700">Pesanan tidak ditemukan.</p>
        <Link href="/orders" className="text-xs font-bold text-brand-600 hover:text-brand-700 mt-4 inline-block">
          Kembali ke Pesanan Saya
        </Link>
      </div>
    );
  }

  const qrValue = order.qr_token || order.invoice_no;

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <Link href="/orders" className="inline-flex items-center space-x-1 text-xs font-bold text-slate-500 hover:text-slate-800 transition">
        <ArrowLeft className="w-4 h-4" />
        <span>Kembali ke Pesanan Saya</span>
      </Link>

      <div className="bg-white rounded-2xl sm:rounded-3xl border border-slate-200 p-4 sm:p-8 shadow-sm space-y-5 sm:space-y-6">
        <div className="flex items-start justify-between flex-wrap gap-2 border-b border-slate-100 pb-4">
          <div className="min-w-0">
            <h2 className="text-lg sm:text-xl font-extrabold text-slate-900 break-all">{order.invoice_no}</h2>
            <p className="text-xs text-slate-400 mt-0.5">
              {new Date(order.created_at).toLocaleDateString('id-ID', {
                day: 'numeric',
                month: 'long',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
              })}
            </p>
          </div>
          <span
            className={`px-3 py-1 rounded-full text-xs font-bold uppercase shrink-0 ${
              order.status === 'paid'
                ? 'bg-emerald-100 text-emerald-800'
                : order.status === 'pending'
                ? 'bg-amber-100 text-amber-800'
                : 'bg-slate-100 text-slate-700'
            }`}
          >
            {order.status === 'pending' && (order.payment_method === 'pharmacy' || order.payment_method === 'bayar_di_apotek')
              ? 'Bayar di Kasir (Apotek)'
              : order.status}
          </span>
        </div>

        {/* Online Payment Instruction Box for Pending Orders */}
        {order.status === 'pending' &&
          order.payment_method !== 'pharmacy' &&
          order.payment_method !== 'bayar_di_apotek' && (
            <div className="bg-gradient-to-r from-amber-50/80 to-orange-50/80 border border-amber-200 rounded-2xl p-4 sm:p-5 space-y-3">
              <div className="flex items-center justify-between flex-wrap gap-1">
                <div className="flex items-center space-x-1.5 text-xs font-extrabold text-amber-900">
                  <CreditCard className="w-4 h-4 text-amber-700" />
                  <span>
                    {paymentDetails?.bank_name
                      ? `Virtual Account ${paymentDetails.bank_name}`
                      : paymentDetails?.qr_url
                      ? 'Pembayaran QRIS Midtrans'
                      : 'Pembayaran Online Midtrans'}
                  </span>
                </div>
                {paymentDetails?.expiry_time && (
                  <span className="text-[10px] font-bold text-amber-700 bg-amber-100 px-2 py-0.5 rounded-full">
                    Batas Bayar: {paymentDetails.expiry_time}
                  </span>
                )}
              </div>

              {paymentDetails?.va_number ? (
                <div className="flex items-center justify-between gap-2 flex-wrap bg-white border border-amber-200 rounded-xl px-3.5 sm:px-4 py-2.5">
                  <div className="min-w-0">
                    <span className="text-[10px] text-slate-400 block font-medium">Nomor Virtual Account</span>
                    <span className="text-base sm:text-lg font-black tracking-wider font-mono text-slate-900 break-all">
                      {paymentDetails.va_number}
                    </span>
                  </div>
                  <button
                    onClick={() => copyToClipboard(paymentDetails.va_number)}
                    className="px-3 py-1.5 bg-amber-50 hover:bg-amber-100 active:bg-amber-200 border border-amber-200 rounded-lg text-amber-900 text-xs font-bold transition flex items-center space-x-1 shrink-0"
                  >
                    {copiedVa ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copiedVa ? 'Tersalin' : 'Salin'}</span>
                  </button>
                </div>
              ) : paymentDetails?.bill_key ? (
                <div className="bg-white border border-amber-200 rounded-xl p-3 text-xs space-y-1">
                  <div><span className="text-slate-400">Kode Perusahaan (Biller): </span><span className="font-mono font-bold text-slate-900">{paymentDetails.biller_code}</span></div>
                  <div><span className="text-slate-400">Kode Pembayaran (Bill Key): </span><span className="font-mono font-bold text-slate-900">{paymentDetails.bill_key}</span></div>
                </div>
              ) : paymentDetails?.qr_url ? (
                <div className="bg-white border border-amber-200 rounded-xl p-3.5 flex flex-col sm:flex-row items-center gap-4">
                  <img
                    src={paymentDetails.qr_url}
                    alt={`QRIS ${order.invoice_no}`}
                    className="w-32 h-32 object-contain rounded-lg border border-slate-100 bg-white flex-shrink-0"
                  />
                  <div className="text-xs text-amber-900 space-y-1 text-center sm:text-left">
                    <p className="font-bold">Scan QRIS di atas untuk menyelesaikan pembayaran.</p>
                    <p className="text-[11px] text-amber-700">
                      Setelah membayar, klik <strong>Cek Status</strong> atau buka popup lewat tombol <strong>Bayar Sekarang</strong>.
                    </p>
                  </div>
                </div>
              ) : (
                <div className="flex items-start space-x-2 text-xs text-amber-800">
                  <AlertCircle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                  <p>
                    Popup pembayaran sempat ditutup sebelum selesai. Silakan klik tombol <strong>Bayar Sekarang</strong> di bawah untuk membuka kembali pilihan pembayaran (Bank BCA, Mandiri, BRI, QRIS, dll).
                  </p>
                </div>
              )}

              {/* Action Buttons in Order Detail */}
              <div className="pt-2 flex items-center flex-wrap gap-2">
                <button
                  onClick={handlePayOnline}
                  disabled={paying}
                  className="flex-1 sm:flex-initial px-4 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-md flex items-center justify-center space-x-1.5 transition"
                >
                  {paying ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <CreditCard className="w-3.5 h-3.5" />}
                  <span>{paying ? 'Membuka...' : paymentDetails?.va_number ? 'Buka Popup / Ganti Metode' : 'Bayar Sekarang'}</span>
                </button>

                <button
                  onClick={handleVerifyPayment}
                  disabled={verifying}
                  className="px-3.5 py-2.5 bg-amber-500 hover:bg-amber-600 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-sm flex items-center justify-center space-x-1.5 transition"
                >
                  <RefreshCw className={`w-3.5 h-3.5 ${verifying ? 'animate-spin' : ''}`} />
                  <span>{verifying ? 'Memeriksa...' : 'Cek Status'}</span>
                </button>

                <button
                  onClick={handleCancelOrder}
                  disabled={cancelling}
                  className="px-3 py-2.5 border border-red-200 text-red-600 hover:bg-red-50 disabled:opacity-50 font-bold text-xs rounded-xl flex items-center justify-center space-x-1 transition"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  <span>{cancelling ? 'Membatalkan...' : 'Batalkan'}</span>
                </button>
              </div>
            </div>
          )}

        {/* QR Code Section (for paid orders OR Bayar di Apotek) */}
        {(order.status === 'paid' || (order.status === 'pending' && (order.payment_method === 'pharmacy' || order.payment_method === 'bayar_di_apotek'))) && (
          <div className="bg-brand-50/60 rounded-3xl border-2 border-dashed border-brand-300 p-6 text-center space-y-3">
            <h3 className="font-bold text-brand-900 text-sm">
              {order.status === 'paid' ? 'QR Pengambilan Obat di Toko' : 'QR Pesanan Bayar di Kasir'}
            </h3>
            <p className="text-xs text-brand-700 max-w-sm mx-auto">
              {order.status === 'paid'
                ? 'Perlihatkan kode QR di bawah ini ke kasir Apotek Santosa Farma untuk mengambil pesanan Anda yang sudah lunas:'
                : 'Perlihatkan kode QR ini ke kasir Apotek Santosa Farma untuk pengecekan pesanan dan pembayaran di tempat (Tunai / QRIS):'}
            </p>
            <div className="p-4 bg-white rounded-2xl inline-block shadow-sm">
              <QRCodeSVG value={qrValue} size={180} level="H" includeMargin />
            </div>
            <p className="text-[11px] font-mono text-slate-500">{qrValue}</p>
          </div>
        )}

        {/* Order Items */}
        <div className="space-y-3">
          <h4 className="text-xs font-bold text-slate-500 uppercase tracking-wider">Daftar Obat</h4>
          <div className="divide-y divide-slate-100">
            {order.items?.map((item) => (
              <div key={item.id} className="py-2.5 flex items-center justify-between gap-3 text-xs">
                <div className="min-w-0 flex-1">
                  <span className="font-bold text-slate-800 break-words">{item.product_name}</span>
                  <span className="text-slate-400 block">{item.qty} x Rp {Number(item.price).toLocaleString('id-ID')}</span>
                </div>
                <span className="font-extrabold text-slate-900 shrink-0">
                  Rp {Number(item.subtotal).toLocaleString('id-ID')}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Total */}
        <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
          <span className="text-sm font-bold text-slate-700">Total Pembayaran</span>
          <span className="text-xl font-black text-brand-700">
            Rp {Number(order.total).toLocaleString('id-ID')}
          </span>
        </div>
      </div>
    </div>
  );
}
