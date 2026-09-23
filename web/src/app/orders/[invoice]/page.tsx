'use client';

import React, { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { API_BASE_URL, Transaction } from '@/lib/api';
import { QRCodeSVG } from 'qrcode.react';
import { ArrowLeft, CheckCircle2, QrCode, FileText } from 'lucide-react';
import Link from 'next/link';

export default function OrderDetailPage() {
  const params = useParams();
  const router = useRouter();
  const { user, token, loading: authLoading } = useAuth();
  const invoiceNo = params.invoice as string;

  const [order, setOrder] = useState<Transaction | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (authLoading) return;

    if (!token || !user) {
      router.replace(`/login?redirect=/orders/${invoiceNo}`);
      return;
    }

    const fetchOrder = async () => {
      try {
        const res = await fetch(`${API_BASE_URL}/transactions/customer/my-orders`, {
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/json',
          },
        });
        if (res.ok) {
          const json = await res.json();
          const found = json.data.find((o: Transaction) => o.invoice_no === invoiceNo);
          setOrder(found || null);
        }
      } catch (err) {
        console.error('Error fetching order detail', err);
      } finally {
        setLoading(false);
      }
    };

    fetchOrder();
  }, [user, token, authLoading, invoiceNo, router]);

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

      <div className="bg-white rounded-3xl border border-slate-200 p-6 sm:p-8 shadow-sm space-y-6">
        <div className="flex items-center justify-between border-b border-slate-100 pb-4">
          <div>
            <h2 className="text-xl font-extrabold text-slate-900">{order.invoice_no}</h2>
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
          <span className="px-3 py-1 bg-emerald-100 text-emerald-800 rounded-full text-xs font-bold uppercase">
            {order.status}
          </span>
        </div>

        {/* QR Code Section (if paid) */}
        {order.status === 'paid' && (
          <div className="bg-brand-50/60 rounded-3xl border-2 border-dashed border-brand-300 p-6 text-center space-y-3">
            <h3 className="font-bold text-brand-900 text-sm">QR Pengambilan Obat di Toko</h3>
            <p className="text-xs text-brand-700 max-w-sm mx-auto">
              Perlihatkan kode QR di bawah ini ke kasir Apotek Santosa Farma untuk mengambil pesanan Anda:
            </p>
            <div className="p-4 bg-white rounded-2xl inline-block shadow-sm">
              <QRCodeSVG value={qrValue} size={180} level="H" includeMargin />
            </div>
            <p className="text-[11px] font-mono text-slate-500">{order.qr_token}</p>
          </div>
        )}

        {/* Order Items */}
        <div className="space-y-3">
          <h4 className="text-xs font-bold text-slate-500 uppercase tracking-wider">Daftar Obat</h4>
          <div className="divide-y divide-slate-100">
            {order.items?.map((item) => (
              <div key={item.id} className="py-2.5 flex items-center justify-between text-xs">
                <div>
                  <span className="font-bold text-slate-800">{item.product_name}</span>
                  <span className="text-slate-400 block">{item.qty} x Rp {item.price.toLocaleString('id-ID')}</span>
                </div>
                <span className="font-extrabold text-slate-900">
                  Rp {item.subtotal.toLocaleString('id-ID')}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Total */}
        <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
          <span className="text-sm font-bold text-slate-700">Total Pembayaran</span>
          <span className="text-xl font-black text-brand-700">
            Rp {order.total.toLocaleString('id-ID')}
          </span>
        </div>
      </div>
    </div>
  );
}

