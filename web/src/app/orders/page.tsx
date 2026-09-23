'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { API_BASE_URL, Transaction } from '@/lib/api';
import QrPickupModal from '@/components/QrPickupModal';
import { Package, QrCode, Clock, CheckCircle2, AlertCircle, Eye, ShoppingBag } from 'lucide-react';

export default function MyOrdersPage() {
  const router = useRouter();
  const { user, token, loading: authLoading } = useAuth();

  const [orders, setOrders] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'all' | 'pending' | 'paid' | 'diambil'>('all');
  const [selectedTrx, setSelectedTrx] = useState<Transaction | null>(null);
  const [showQrModal, setShowQrModal] = useState(false);

  useEffect(() => {
    if (authLoading) return;

    if (!token || !user) {
      router.replace('/login?redirect=/orders');
      return;
    }

    const fetchOrders = async () => {
      try {
        const res = await fetch(`${API_BASE_URL}/transactions/customer/my-orders`, {
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/json',
          },
        });
        if (res.ok) {
          const json = await res.json();
          setOrders(json.data);
        }
      } catch (err) {
        console.error('Error fetching orders', err);
      } finally {
        setLoading(false);
      }
    };

    fetchOrders();
  }, [user, token, authLoading, router]);

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

  const getStatusBadge = (status: string) => {
    switch (status) {
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
            Menunggu Pembayaran
          </span>
        );
      default:
        return (
          <span className="px-3 py-1 bg-slate-100 text-slate-700 rounded-full text-xs font-bold">
            {status}
          </span>
        );
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <Package className="w-6 h-6 text-brand-600" />
          <h2 className="text-2xl font-black text-slate-900">Pesanan Saya</h2>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex items-center space-x-2 border-b border-slate-200 pb-2 overflow-x-auto">
        {[
          { id: 'all', label: 'Semua Pesanan' },
          { id: 'paid', label: 'Siap Diambil (QR)' },
          { id: 'pending', label: 'Menunggu Pembayaran' },
          { id: 'diambil', label: 'Selesai Diambil' },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition whitespace-nowrap ${
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
            <div key={i} className="bg-white rounded-3xl p-6 border border-slate-200 animate-pulse space-y-3">
              <div className="h-4 bg-slate-100 rounded w-1/4" />
              <div className="h-10 bg-slate-100 rounded" />
              <div className="h-4 bg-slate-100 rounded w-1/3" />
            </div>
          ))}
        </div>
      ) : filteredOrders.length === 0 ? (
        <div className="bg-white rounded-3xl border border-slate-200 p-12 text-center text-slate-400">
          <ShoppingBag className="w-12 h-12 mx-auto mb-3 text-slate-300" />
          <h4 className="font-bold text-slate-700">Belum ada transaksi di tab ini</h4>
          <p className="text-xs text-slate-400 mt-1">Pesanan online yang Anda buat akan tercatat di sini.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredOrders.map((order) => (
            <div
              key={order.id}
              className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm hover:shadow-md transition space-y-4"
            >
              <div className="flex items-center justify-between flex-wrap gap-2 pb-3 border-b border-slate-100">
                <div>
                  <span className="text-xs font-bold text-slate-900 block">{order.invoice_no}</span>
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
                <div>{getStatusBadge(order.status)}</div>
              </div>

              {/* Items */}
              <div className="space-y-2">
                {order.items?.map((item) => (
                  <div key={item.id} className="flex justify-between text-xs">
                    <span className="text-slate-700 font-medium">
                      {item.qty}x {item.product_name}
                    </span>
                    <span className="font-bold text-slate-900">
                      Rp {item.subtotal.toLocaleString('id-ID')}
                    </span>
                  </div>
                ))}
              </div>

              {/* Total & Action Buttons */}
              <div className="pt-3 border-t border-slate-100 flex items-center justify-between flex-wrap gap-3">
                <div>
                  <span className="text-[11px] text-slate-400 block font-medium">Total Pembayaran</span>
                  <span className="text-base font-extrabold text-slate-900">
                    Rp {order.total.toLocaleString('id-ID')}
                  </span>
                </div>

                <div className="flex items-center space-x-2">
                  {order.status === 'paid' && (
                    <button
                      onClick={() => {
                        setSelectedTrx(order);
                        setShowQrModal(true);
                      }}
                      className="px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-bold text-xs rounded-xl shadow-md flex items-center space-x-1.5 transition"
                    >
                      <QrCode className="w-4 h-4" />
                      <span>Lihat QR Pengambilan</span>
                    </button>
                  )}

                  {order.status === 'diambil' && (
                    <button
                      onClick={() => window.open(`${API_BASE_URL}/receipts/${order.id}/pdf`, '_blank')}
                      className="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition"
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

