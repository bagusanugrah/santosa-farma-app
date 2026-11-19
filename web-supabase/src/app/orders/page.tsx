'use client';

import React, { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { API_BASE_URL, Transaction } from '@/lib/api';
import QrPickupModal from '@/components/QrPickupModal';
import { Package, QrCode, RefreshCw, ShoppingBag } from 'lucide-react';

export default function MyOrdersPage() {
  const router = useRouter();
  const { user, token, loading: authLoading } = useAuth();

  const [orders, setOrders] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [verifyingInvoice, setVerifyingInvoice] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'all' | 'pending' | 'paid' | 'diambil'>('all');
  const [selectedTrx, setSelectedTrx] = useState<Transaction | null>(null);
  const [showQrModal, setShowQrModal] = useState(false);

  const fetchOrders = useCallback(async () => {
    if (!token) return;
    try {
      const res = await fetch(`${API_BASE_URL}/transactions/customer/my-orders`, {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
        },
      });
      if (res.ok) {
        const json = await res.json();
        setOrders(json.data || []);
      }
    } catch (err) {
      console.error('Error fetching orders', err);
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    if (authLoading) return;

    if (!token || !user) {
      router.replace('/login?redirect=/orders');
      return;
    }

    fetchOrders();
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
        await fetchOrders();
      }
    } catch (err) {
      console.error('Error verifying payment:', err);
    } finally {
      setVerifyingInvoice(null);
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
      </div>

      {/* Tabs */}
      <div className="flex items-center space-x-2 border-b border-slate-200 pb-2 overflow-x-auto scrollbar-none -mx-3.5 px-3.5 sm:mx-0 sm:px-0">
        {[
          { id: 'all', label: 'Semua Pesanan' },
          { id: 'paid', label: 'Siap Diambil (QR)' },
          { id: 'pending', label: 'Menunggu Pembayaran' },
          { id: 'diambil', label: 'Selesai Diambil' },
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
                  <div key={item.id} className="flex justify-between text-xs">
                    <span className="text-slate-700 font-medium">
                      {item.qty}x {item.product_name}
                    </span>
                    <span className="font-bold text-slate-900">
                      Rp {Number(item.subtotal).toLocaleString('id-ID')}
                    </span>
                  </div>
                ))}
              </div>

              {/* Total & Action Buttons */}
              <div className="pt-3 border-t border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div className="flex sm:flex-col justify-between sm:justify-start items-center sm:items-start">
                  <span className="text-[11px] text-slate-400 block font-medium">Total Pembayaran</span>
                  <span className="text-base font-extrabold text-slate-900">
                    Rp {Number(order.total).toLocaleString('id-ID')}
                  </span>
                </div>

                <div className="flex items-center space-x-2 w-full sm:w-auto">
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
                    <button
                      onClick={() => handleVerifyPayment(order.invoice_no)}
                      disabled={verifyingInvoice === order.invoice_no}
                      className="w-full sm:w-auto justify-center px-4 py-2.5 bg-amber-500 hover:bg-amber-600 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-sm flex items-center space-x-1.5 transition"
                    >
                      <RefreshCw
                        className={`w-3.5 h-3.5 ${verifyingInvoice === order.invoice_no ? 'animate-spin' : ''}`}
                      />
                      <span>
                        {verifyingInvoice === order.invoice_no ? 'Memeriksa...' : 'Cek Status Bayar'}
                      </span>
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

