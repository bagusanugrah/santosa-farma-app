'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { useStaffAuth } from '@/context/StaffAuthContext';
import { API_BASE_URL, Product, Transaction } from '@/lib/api';
import ReceiptModal from '@/components/ReceiptModal';
import { QRCodeSVG } from 'qrcode.react';
import {
  Search,
  Plus,
  Minus,
  Trash2,
  Banknote,
  QrCode,
  CheckCircle2,
  RefreshCw,
  AlertCircle,
  Pill,
  ShoppingBag,
} from 'lucide-react';

interface CartItem {
  product: Product;
  qty: number;
}

export default function PosPage() {
  const router = useRouter();
  const { user, token } = useStaffAuth();

  const [products, setProducts] = useState<Product[]>([]);
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [cart, setCart] = useState<CartItem[]>([]);
  const [paymentMethod, setPaymentMethod] = useState<'tunai' | 'qris'>('tunai');
  const [cashAmount, setCashAmount] = useState<string>('');
  const [showAndroidQrisToggle, setShowAndroidQrisToggle] = useState(false);

  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState('');
  const [activeQrisTrx, setActiveQrisTrx] = useState<Transaction | null>(null);
  const [completedTrx, setCompletedTrx] = useState<Transaction | null>(null);
  const [showReceiptModal, setShowReceiptModal] = useState(false);

  const categories = [
    'all',
    'Analgesik',
    'Antibiotik',
    'Flu & Batuk',
    'Herbal',
    'Mata',
    'Minyak Angin',
    'Obat Cacing',
    'P3K',
    'Pencernaan',
    'Vitamin',
    'Daya Tahan Tubuh',
  ];

  const fetchProductList = useCallback(async () => {
    try {
      const query = new URLSearchParams();
      if (search) query.append('search', search);
      if (selectedCategory !== 'all') query.append('category', selectedCategory);
      query.append('per_page', '100');
      query.append('sort', 'alphabet');

      const res = await fetch(`${API_BASE_URL}/products?${query.toString()}`);
      if (res.ok) {
        const json = await res.json();
        setProducts(json.data);
      }
    } catch (err) {
      console.error('Error fetching products', err);
    }
  }, [search, selectedCategory]);

  useEffect(() => {
    if (!token && !user) {
      router.push('/login');
      return;
    }
    fetchProductList();
  }, [user, token, fetchProductList, router]);

  // Polling for QRIS transaction status if active
  useEffect(() => {
    if (!activeQrisTrx) return;

    const interval = setInterval(async () => {
      try {
        const res = await fetch(`${API_BASE_URL}/transactions/show/${activeQrisTrx.id}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) {
          const json = await res.json();
          if (json.data.status === 'selesai' || json.data.status === 'paid') {
            setCompletedTrx(json.data);
            setActiveQrisTrx(null);
            setShowReceiptModal(true);
            setCart([]);
            fetchProductList();
          }
        }
      } catch (err) {
        console.error('Error polling QRIS transaction', err);
      }
    }, 3000);

    return () => clearInterval(interval);
  }, [activeQrisTrx, token, fetchProductList]);

  const addToCart = (product: Product) => {
    if (product.stock <= 0) return;
    setCart((prev) => {
      const existing = prev.find((item) => item.product.id === product.id);
      if (existing) {
        if (existing.qty >= product.stock) {
          alert(`Maksimal stok tersedia adalah ${product.stock}`);
          return prev;
        }
        return prev.map((item) =>
          item.product.id === product.id ? { ...item, qty: item.qty + 1 } : item
        );
      }
      return [...prev, { product, qty: 1 }];
    });
  };

  const updateCartQty = (productId: number, qty: number) => {
    if (qty <= 0) {
      removeFromCart(productId);
      return;
    }
    setCart((prev) =>
      prev.map((item) => {
        if (item.product.id === productId) {
          return { ...item, qty: Math.min(qty, item.product.stock) };
        }
        return item;
      })
    );
  };

  const removeFromCart = (productId: number) => {
    setCart((prev) => prev.filter((item) => item.product.id !== productId));
  };

  const totalPrice = cart.reduce((sum, i) => sum + i.product.price * i.qty, 0);
  const parsedCash = parseFloat(cashAmount) || 0;
  const changeAmount = Math.max(0, parsedCash - totalPrice);

  const handleCheckout = async () => {
    if (cart.length === 0) return;
    if (paymentMethod === 'tunai' && parsedCash < totalPrice) {
      setError('Uang tunai yang dibayarkan kurang dari total tagihan.');
      return;
    }

    setProcessing(true);
    setError('');

    try {
      const payload = {
        payment_method: paymentMethod,
        amount_paid: paymentMethod === 'tunai' ? parsedCash : totalPrice,
        items: cart.map((item) => ({
          product_id: item.product.id,
          qty: item.qty,
        })),
      };

      const res = await fetch(`${API_BASE_URL}/transactions/pos`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      });

      const json = await res.json();
      if (!res.ok) throw new Error(json.message || 'Gagal memproses transaksi.');

      const trx: Transaction = json.data;

      if (paymentMethod === 'tunai') {
        setCompletedTrx(trx);
        setShowReceiptModal(true);
        setCart([]);
        setCashAmount('');
        fetchProductList();
      } else {
        // QRIS
        setActiveQrisTrx(trx);
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div className="flex-1 flex overflow-hidden">
      {/* Left: Product Picker */}
      <div className="flex-1 flex flex-col p-6 overflow-hidden border-r border-slate-200">
        {/* Top Header & Search */}
        <div className="flex items-center justify-between mb-4 gap-4">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Cari obat berdasarkan nama, kategori, indikasi..."
              className="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl focus:border-brand-500 text-xs outline-none font-medium shadow-sm"
            />
          </div>
          <button
            onClick={fetchProductList}
            className="p-2.5 bg-white border border-slate-200 hover:bg-slate-50 text-slate-600 rounded-xl shadow-sm transition"
            title="Refresh Produk"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>

        {/* Categories Bar */}
        <div className="flex items-center space-x-1.5 overflow-x-auto pb-3 scrollbar-none mb-2">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold whitespace-nowrap transition ${
                selectedCategory === cat
                  ? 'bg-brand-600 text-white shadow-sm'
                  : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
              }`}
            >
              {cat === 'all' ? 'Semua Kategori' : cat}
            </button>
          ))}
        </div>

        {/* Product Grid */}
        <div className="flex-1 overflow-y-auto pr-1">
          <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3.5">
            {products.map((product) => {
              const isOutOfStock = product.stock <= 0;
              return (
                <div
                  key={product.id}
                  onClick={() => !isOutOfStock && addToCart(product)}
                  className={`bg-white rounded-2xl border border-slate-200 p-3 flex flex-col justify-between transition cursor-pointer hover:border-brand-400 hover:shadow-md ${
                    isOutOfStock ? 'opacity-50 cursor-not-allowed' : ''
                  }`}
                >
                  <div className="relative w-full h-28 bg-slate-100 rounded-xl overflow-hidden mb-2.5 flex items-center justify-center">
                    {product.image_url ? (
                      <img src={product.image_url} alt={product.name} className="w-full h-full object-cover" />
                    ) : (
                      <Pill className="w-8 h-8 text-slate-400" />
                    )}
                    <span
                      className={`absolute top-1.5 right-1.5 text-[10px] font-bold px-1.5 py-0.5 rounded-md ${
                        isOutOfStock
                          ? 'bg-red-100 text-red-700'
                          : product.stock < 10
                          ? 'bg-amber-100 text-amber-800'
                          : 'bg-emerald-100 text-emerald-800'
                      }`}
                    >
                      Stok: {product.stock}
                    </span>
                  </div>

                  <div>
                    <h4 className="font-bold text-slate-900 text-xs line-clamp-2 leading-snug">
                      {product.name}
                    </h4>
                    <p className="text-[11px] font-extrabold text-brand-700 mt-1">
                      Rp {product.price.toLocaleString('id-ID')}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Right: POS Cart & Payment Panel */}
      <div className="w-96 bg-white border-l border-slate-200 flex flex-col justify-between shadow-xl">
        {/* Cart Header */}
        <div className="p-4 border-b border-slate-200 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <ShoppingBag className="w-5 h-5 text-brand-600" />
            <h3 className="font-bold text-slate-900 text-sm">Keranjang Transaksi</h3>
          </div>
          <span className="text-xs font-bold text-slate-500 bg-slate-100 px-2 py-0.5 rounded-full">
            {cart.reduce((s, i) => s + i.qty, 0)} item
          </span>
        </div>

        {/* Cart Item List */}
        <div className="flex-1 overflow-y-auto p-4 space-y-3">
          {cart.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-center text-slate-400">
              <ShoppingBag className="w-10 h-10 text-slate-300 mb-2" />
              <p className="font-bold text-xs text-slate-600">Keranjang Masih Kosong</p>
              <p className="text-[11px] text-slate-400 mt-0.5">Pilih produk obat di sebelah kiri.</p>
            </div>
          ) : (
            cart.map(({ product, qty }) => (
              <div key={product.id} className="p-2.5 bg-slate-50 rounded-xl border border-slate-100 space-y-2">
                <div className="flex justify-between items-start text-xs">
                  <span className="font-bold text-slate-800 flex-1 pr-2 truncate">{product.name}</span>
                  <span className="font-bold text-slate-900">
                    Rp {(product.price * qty).toLocaleString('id-ID')}
                  </span>
                </div>
                <div className="flex items-center justify-between text-xs pt-1 border-t border-slate-200/60">
                  <span className="text-slate-500 text-[11px]">@ Rp {product.price.toLocaleString('id-ID')}</span>
                  <div className="flex items-center space-x-1.5">
                    <button
                      onClick={() => updateCartQty(product.id, qty - 1)}
                      className="w-5 h-5 bg-white border border-slate-300 rounded flex items-center justify-center hover:bg-slate-100"
                    >
                      <Minus className="w-2.5 h-2.5" />
                    </button>
                    <span className="w-5 text-center font-bold text-slate-800 text-xs">{qty}</span>
                    <button
                      onClick={() => updateCartQty(product.id, qty + 1)}
                      disabled={qty >= product.stock}
                      className="w-5 h-5 bg-white border border-slate-300 rounded flex items-center justify-center hover:bg-slate-100 disabled:opacity-50"
                    >
                      <Plus className="w-2.5 h-2.5" />
                    </button>
                    <button
                      onClick={() => removeFromCart(product.id)}
                      className="p-1 text-slate-400 hover:text-red-600 ml-1"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Payment Configuration Panel */}
        <div className="p-4 border-t border-slate-200 bg-slate-50 space-y-3">
          {error && (
            <div className="p-2 bg-red-50 border border-red-200 text-red-700 text-[11px] font-semibold rounded-lg flex items-center space-x-1.5">
              <AlertCircle className="w-3.5 h-3.5 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {/* Total Tagihan */}
          <div className="flex justify-between items-center bg-white p-3 rounded-xl border border-slate-200">
            <span className="text-xs font-bold text-slate-500">TOTAL:</span>
            <span className="text-xl font-black text-slate-900">
              Rp {totalPrice.toLocaleString('id-ID')}
            </span>
          </div>

          {/* Payment Method Switch */}
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={() => setPaymentMethod('tunai')}
              className={`py-2 rounded-xl text-xs font-bold flex items-center justify-center space-x-1.5 transition ${
                paymentMethod === 'tunai'
                  ? 'bg-slate-900 text-white shadow-sm'
                  : 'bg-white text-slate-600 border border-slate-200'
              }`}
            >
              <Banknote className="w-4 h-4" />
              <span>Tunai</span>
            </button>
            <button
              onClick={() => setPaymentMethod('qris')}
              className={`py-2 rounded-xl text-xs font-bold flex items-center justify-center space-x-1.5 transition ${
                paymentMethod === 'qris'
                  ? 'bg-brand-600 text-white shadow-sm'
                  : 'bg-white text-slate-600 border border-slate-200'
              }`}
            >
              <QrCode className="w-4 h-4" />
              <span>QRIS</span>
            </button>
          </div>

          {/* Cash Input if Tunai */}
          {paymentMethod === 'tunai' && (
            <div className="space-y-2 pt-1">
              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Uang Diterima (Rp)</label>
                <input
                  type="number"
                  value={cashAmount}
                  onChange={(e) => setCashAmount(e.target.value)}
                  placeholder={totalPrice.toString()}
                  className="w-full px-3 py-2 bg-white border border-slate-300 rounded-xl text-xs font-bold focus:border-brand-500 outline-none"
                />
              </div>

              {/* Quick Cash Buttons */}
              <div className="flex items-center space-x-1.5 overflow-x-auto pb-1">
                {[totalPrice, 20000, 50000, 100000].map((amt) => (
                  <button
                    key={amt}
                    onClick={() => setCashAmount(amt.toString())}
                    className="px-2 py-1 bg-white border border-slate-200 hover:bg-slate-100 rounded text-[10px] font-semibold text-slate-700 whitespace-nowrap"
                  >
                    Pas/Rp {amt.toLocaleString('id-ID')}
                  </button>
                ))}
              </div>

              <div className="flex justify-between items-center text-xs pt-1 font-bold">
                <span className="text-slate-500">Kembalian:</span>
                <span className="text-emerald-700 text-sm">Rp {changeAmount.toLocaleString('id-ID')}</span>
              </div>
            </div>
          )}

          {/* QRIS Active Modal / Info */}
          {paymentMethod === 'qris' && (
            <div className="p-3 bg-white rounded-xl border border-brand-200 text-center space-y-2">
              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-600 font-medium">Tampilkan di HP Kasir:</span>
                <input
                  type="checkbox"
                  checked={showAndroidQrisToggle}
                  onChange={(e) => setShowAndroidQrisToggle(e.target.checked)}
                  className="rounded text-brand-600 focus:ring-brand-500 w-4 h-4"
                />
              </div>
              <p className="text-[10px] text-slate-400">
                {showAndroidQrisToggle
                  ? 'Pelanggan dapat scan QRIS langsung dari aplikasi Android Kasir.'
                  : 'QR Code QRIS akan ditampilkan di layar desktop ini.'}
              </p>
            </div>
          )}

          {/* Checkout Button */}
          <button
            onClick={handleCheckout}
            disabled={processing || cart.length === 0}
            className="w-full py-3.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-extrabold text-xs rounded-xl shadow-md transition flex items-center justify-center space-x-1.5"
          >
            <CheckCircle2 className="w-4 h-4" />
            <span>{processing ? 'Memproses...' : 'Selesaikan Transaksi (F2)'}</span>
          </button>
        </div>
      </div>

      {/* QRIS Active Display Modal (if pending QRIS checkout) */}
      {activeQrisTrx && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-sm">
          <div className="bg-white rounded-3xl max-w-sm w-full p-6 shadow-2xl text-center space-y-4 animate-scale">
            <div className="w-12 h-12 rounded-2xl bg-brand-50 text-brand-600 flex items-center justify-center mx-auto">
              <QrCode className="w-6 h-6" />
            </div>
            <h3 className="font-bold text-slate-900 text-base">Menunggu Pembayaran QRIS</h3>
            <p className="text-xs text-slate-500">
              Silakan minta pelanggan scan kode QR di bawah ini (atau via aplikasi HP Kasir):
            </p>

            <div className="p-4 bg-white rounded-2xl border-2 border-dashed border-slate-300 inline-block">
              <QRCodeSVG
                value={activeQrisTrx.midtrans_qris_url || activeQrisTrx.invoice_no}
                size={180}
                level="M"
                includeMargin
              />
            </div>

            <div className="text-xs bg-slate-50 p-2.5 rounded-xl text-slate-700 space-y-1">
              <div className="flex justify-between">
                <span>Invoice:</span>
                <span className="font-bold">{activeQrisTrx.invoice_no}</span>
              </div>
              <div className="flex justify-between">
                <span>Total:</span>
                <span className="font-extrabold text-brand-700">Rp {activeQrisTrx.total.toLocaleString('id-ID')}</span>
              </div>
            </div>

            <div className="flex items-center justify-center space-x-2 text-xs text-brand-600 animate-pulse font-medium">
              <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              <span>Menunggu notifikasi settlement...</span>
            </div>

            <button
              onClick={() => setActiveQrisTrx(null)}
              className="w-full py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl"
            >
              Tutup / Batalkan Tampilan
            </button>
          </div>
        </div>
      )}

      {/* Struk Modal */}
      <ReceiptModal
        isOpen={showReceiptModal}
        onClose={() => setShowReceiptModal(false)}
        transaction={completedTrx}
      />
    </div>
  );
}

