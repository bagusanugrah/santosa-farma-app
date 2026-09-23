'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { fetchProducts, fetchStoreStatus, Product, MetaPagination } from '@/lib/api';
import ProductCard from '@/components/ProductCard';
import { Search, SlidersHorizontal, ChevronLeft, ChevronRight, AlertTriangle, Sparkles } from 'lucide-react';

export default function CatalogPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [meta, setMeta] = useState<MetaPagination>({
    current_page: 1,
    per_page: 10,
    total: 0,
    last_page: 1,
    from: null,
    to: null,
  });

  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('all');
  const [sort, setSort] = useState('alphabet'); // Default A-Z
  const [perPage, setPerPage] = useState(10);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [isStoreOpen, setIsStoreOpen] = useState(true);

  // Categories list
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

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const storeRes = await fetchStoreStatus();
      setIsStoreOpen(storeRes.is_open);

      if (storeRes.is_open) {
        const res = await fetchProducts({
          search,
          category,
          sort,
          per_page: perPage,
          page,
        });
        setProducts(res.data);
        setMeta(res.meta);
      }
    } catch (err) {
      console.error('Error loading catalog', err);
      setIsStoreOpen(false);
    } finally {
      setLoading(false);
    }
  }, [search, category, sort, perPage, page]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Debounced search reset page
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearch(e.target.value);
    setPage(1);
  };

  const handleCategoryChange = (cat: string) => {
    setCategory(cat);
    setPage(1);
  };

  const handlePerPageChange = (val: number) => {
    setPerPage(val);
    setPage(1);
  };

  return (
    <div className="space-y-8">
      {/* Hero Banner */}
      <div className="bg-gradient-to-br from-brand-800 via-brand-700 to-slate-900 rounded-3xl p-6 sm:p-10 text-white shadow-xl relative overflow-hidden">
        <div className="relative z-10 max-w-2xl">
          <div className="inline-flex items-center space-x-2 bg-white/10 backdrop-blur-md px-3 py-1.5 rounded-full text-xs font-semibold text-brand-200 mb-4 border border-white/10">
            <Sparkles className="w-3.5 h-3.5" />
            <span>Katalog Obat Resmi & Terpercaya</span>
          </div>
          <h2 className="text-2xl sm:text-4xl font-extrabold tracking-tight leading-tight">
            Katalog Produk Obat & Kesehatan
          </h2>
          <p className="text-sm sm:text-base text-brand-100/90 mt-2 font-normal">
            Pesan obat secara online, bayar mudah via QRIS/Transfer, dan ambil langsung di kasir Apotek Santosa Farma menggunakan Kode QR.
          </p>
        </div>
      </div>

      {/* When Store is Closed */}
      {!isStoreOpen && !loading && (
        <div className="bg-amber-50 border-2 border-amber-300 rounded-3xl p-8 text-center max-w-xl mx-auto shadow-sm">
          <div className="w-16 h-16 rounded-full bg-amber-100 text-amber-700 flex items-center justify-center mx-auto mb-4">
            <AlertTriangle className="w-8 h-8" />
          </div>
          <h3 className="text-xl font-bold text-amber-900">Apotek Sedang Tutup</h3>
          <p className="text-sm text-amber-800 mt-2">
            Apotek Santosa Farma saat ini sedang di luar jam operasional kasir. Fitur pencarian katalog dan pemesanan online dinonaktifkan sementara dan akan dibuka kembali saat toko beroperasi.
          </p>
        </div>
      )}

      {/* Active Catalog View */}
      {isStoreOpen && (
        <div className="space-y-6">
          {/* Filter & Search Bar */}
          <div className="bg-white rounded-2xl border border-slate-200 p-4 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
            {/* Search Input */}
            <div className="relative w-full md:w-96">
              <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={search}
                onChange={handleSearchChange}
                placeholder="Cari obat, vitamin, p3k..."
                className="w-full pl-10 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 focus:bg-white focus:border-brand-500 rounded-xl outline-none transition"
              />
            </div>

            {/* Sorting & Per Page controls */}
            <div className="flex items-center space-x-3 w-full md:w-auto justify-end">
              {/* Sort selector */}
              <div className="flex items-center space-x-2 text-xs font-semibold text-slate-600">
                <SlidersHorizontal className="w-3.5 h-3.5 text-slate-400" />
                <span>Urutkan:</span>
                <select
                  value={sort}
                  onChange={(e) => {
                    setSort(e.target.value);
                    setPage(1);
                  }}
                  className="bg-slate-50 border border-slate-200 rounded-lg px-2.5 py-1.5 font-medium text-xs text-slate-800 outline-none focus:border-brand-500"
                >
                  <option value="alphabet">Abjad (A - Z)</option>
                  <option value="name_desc">Abjad (Z - A)</option>
                  <option value="price_asc">Harga Terendah</option>
                  <option value="price_desc">Harga Tertinggi</option>
                  <option value="latest">Terbaru</option>
                </select>
              </div>

              {/* Per Page (10 / 25 / 50 / 100) */}
              <div className="flex items-center space-x-2 text-xs font-semibold text-slate-600 border-l border-slate-200 pl-3">
                <span>Tampil:</span>
                <select
                  value={perPage}
                  onChange={(e) => handlePerPageChange(Number(e.target.value))}
                  className="bg-slate-50 border border-slate-200 rounded-lg px-2 py-1.5 font-medium text-xs text-slate-800 outline-none focus:border-brand-500"
                >
                  <option value={10}>10</option>
                  <option value={25}>25</option>
                  <option value={50}>50</option>
                  <option value={100}>100</option>
                </select>
              </div>
            </div>
          </div>

          {/* Category Pills */}
          <div className="flex items-center space-x-2 overflow-x-auto pb-2 scrollbar-none">
            {categories.map((cat) => (
              <button
                key={cat}
                onClick={() => handleCategoryChange(cat)}
                className={`px-4 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition ${
                  category === cat
                    ? 'bg-brand-600 text-white shadow-sm'
                    : 'bg-white text-slate-600 border border-slate-200 hover:border-slate-300 hover:bg-slate-50'
                }`}
              >
                {cat === 'all' ? 'Semua Kategori' : cat}
              </button>
            ))}
          </div>

          {/* Product Grid */}
          {loading ? (
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4 sm:gap-6">
              {Array.from({ length: perPage }).map((_, i) => (
                <div key={i} className="bg-white rounded-2xl border border-slate-200 p-4 space-y-3 animate-pulse">
                  <div className="w-full h-40 bg-slate-100 rounded-xl" />
                  <div className="h-4 bg-slate-100 rounded w-3/4" />
                  <div className="h-3 bg-slate-100 rounded w-1/2" />
                  <div className="h-8 bg-slate-100 rounded-xl mt-4" />
                </div>
              ))}
            </div>
          ) : products.length === 0 ? (
            <div className="bg-white rounded-3xl border border-slate-200 p-12 text-center text-slate-500">
              <p className="text-base font-bold text-slate-700">Tidak ada produk obat yang sesuai.</p>
              <p className="text-xs text-slate-400 mt-1">Coba kata kunci pencarian atau kategori lain.</p>
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4 sm:gap-6">
              {products.map((product) => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          )}

          {/* Pagination Controls */}
          {meta.total > 0 && (
            <div className="bg-white rounded-2xl border border-slate-200 px-4 py-3 flex items-center justify-between shadow-sm">
              <div className="text-xs text-slate-500">
                Menampilkan <strong className="text-slate-800">{meta.from ?? 0}</strong> -{' '}
                <strong className="text-slate-800">{meta.to ?? 0}</strong> dari{' '}
                <strong className="text-slate-800">{meta.total}</strong> produk
              </div>

              <div className="flex items-center space-x-2">
                <button
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page <= 1}
                  className="p-2 rounded-lg border border-slate-200 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition text-slate-700"
                >
                  <ChevronLeft className="w-4 h-4" />
                </button>
                <span className="text-xs font-bold text-slate-800 px-2">
                  Halaman {meta.current_page} dari {meta.last_page}
                </span>
                <button
                  onClick={() => setPage((p) => Math.min(meta.last_page, p + 1))}
                  disabled={page >= meta.last_page}
                  className="p-2 rounded-lg border border-slate-200 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition text-slate-700"
                >
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

