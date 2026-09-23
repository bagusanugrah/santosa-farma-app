'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useStaffAuth } from '@/context/StaffAuthContext';
import { API_BASE_URL } from '@/lib/api';
import { FileSpreadsheet, FileText, Download, Calendar, CheckCircle2, Shield } from 'lucide-react';

export default function AdminExportPage() {
  const router = useRouter();
  const { user, token } = useStaffAuth();

  const [startDate, setStartDate] = useState(
    new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  );
  const [endDate, setEndDate] = useState(new Date().toISOString().split('T')[0]);
  const [downloadingPdf, setDownloadingPdf] = useState(false);
  const [downloadingExcel, setDownloadingExcel] = useState(false);

  useEffect(() => {
    if (!token && !user) {
      router.push('/login');
      return;
    }
    if (user && user.role !== 'super_admin') {
      router.push('/pos');
      return;
    }
  }, [user, token, router]);

  const handleDownloadSalesPdf = () => {
    setDownloadingPdf(true);
    const url = `${API_BASE_URL}/reports/sales-pdf?start_date=${startDate}&end_date=${endDate}`;

    // Trigger download with auth header
    fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    })
      .then((res) => {
        if (!res.ok) throw new Error('Gagal mengunduh laporan PDF');
        return res.blob();
      })
      .then((blob) => {
        const downloadUrl = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = downloadUrl;
        a.download = `laporan-penjualan-${startDate}-sd-${endDate}.pdf`;
        document.body.appendChild(a);
        a.click();
        a.remove();
      })
      .catch((err) => alert(err.message))
      .finally(() => setDownloadingPdf(false));
  };

  const handleDownloadProductsExcel = () => {
    setDownloadingExcel(true);
    const url = `${API_BASE_URL}/reports/products-excel`;

    fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    })
      .then((res) => {
        if (!res.ok) throw new Error('Gagal mengunduh file Excel');
        return res.blob();
      })
      .then((blob) => {
        const downloadUrl = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = downloadUrl;
        a.download = `daftar-produk-obat-${new Date().toISOString().split('T')[0]}.xlsx`;
        document.body.appendChild(a);
        a.click();
        a.remove();
      })
      .catch((err) => alert(err.message))
      .finally(() => setDownloadingExcel(false));
  };

  return (
    <div className="flex-1 p-8 space-y-8 overflow-y-auto max-w-5xl">
      {/* Header */}
      <div>
        <h2 className="text-xl font-extrabold text-slate-900 flex items-center space-x-2">
          <FileSpreadsheet className="w-6 h-6 text-brand-600" />
          <span>Pusat Laporan & Export Data</span>
        </h2>
        <p className="text-xs text-slate-500 mt-0.5">
          Unduh laporan rekap transaksi (PDF) dan ekspor master katalog produk obat (Excel)
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Export PDF Laporan Penjualan */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm flex flex-col justify-between space-y-6">
          <div className="space-y-4">
            <div className="flex items-center space-x-3">
              <div className="w-12 h-12 rounded-2xl bg-red-100 text-red-600 flex items-center justify-center flex-shrink-0 shadow-sm">
                <FileText className="w-6 h-6" />
              </div>
              <div>
                <h3 className="font-bold text-slate-900 text-sm">Rekap Laporan Penjualan (PDF)</h3>
                <p className="text-xs text-slate-400 mt-0.5">Format dokumen cetak resmi DomPDF</p>
              </div>
            </div>

            <p className="text-xs text-slate-600 leading-relaxed">
              Menghasilkan dokumen PDF berisi total omset, jumlah transaksi toko vs online, rincian pembayaran, dan daftar transaksi pada periode yang dipilih.
            </p>

            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100 space-y-3">
              <label className="block text-xs font-bold text-slate-700">Pilih Rentang Periode Tanggal</label>
              <div className="grid grid-cols-2 gap-2 text-xs">
                <div>
                  <span className="text-[10px] text-slate-400 block mb-1">Dari Tanggal:</span>
                  <input
                    type="date"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl outline-none font-medium focus:border-brand-500 text-xs"
                  />
                </div>
                <div>
                  <span className="text-[10px] text-slate-400 block mb-1">Sampai Tanggal:</span>
                  <input
                    type="date"
                    value={endDate}
                    onChange={(e) => setEndDate(e.target.value)}
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl outline-none font-medium focus:border-brand-500 text-xs"
                  />
                </div>
              </div>
            </div>
          </div>

          <button
            onClick={handleDownloadSalesPdf}
            disabled={downloadingPdf}
            className="w-full py-3.5 bg-red-600 hover:bg-red-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-md transition flex items-center justify-center space-x-2"
          >
            <Download className="w-4 h-4" />
            <span>{downloadingPdf ? 'Mengunduh Dokumen...' : 'Download Rekap Penjualan (.PDF)'}</span>
          </button>
        </div>

        {/* Export Excel Daftar Produk */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm flex flex-col justify-between space-y-6">
          <div className="space-y-4">
            <div className="flex items-center space-x-3">
              <div className="w-12 h-12 rounded-2xl bg-emerald-100 text-emerald-700 flex items-center justify-center flex-shrink-0 shadow-sm">
                <FileSpreadsheet className="w-6 h-6" />
              </div>
              <div>
                <h3 className="font-bold text-slate-900 text-sm">Daftar Produk Obat (Excel)</h3>
                <p className="text-xs text-slate-400 mt-0.5">Spreadsheet (.xlsx) terformat</p>
              </div>
            </div>

            <p className="text-xs text-slate-600 leading-relaxed">
              Ekspor seluruh master data obat Apotek Santosa Farma termasuk nama obat, kategori, harga satuan terkini, stok tersisa, dan deskripsi produk dalam format spreadsheet Microsoft Excel.
            </p>

            <div className="bg-emerald-50/50 p-4 rounded-2xl border border-emerald-100 space-y-2 text-xs text-emerald-800">
              <div className="flex items-center space-x-2 font-bold">
                <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                <span>Format Standar Siap Olah</span>
              </div>
              <p className="text-[11px] text-emerald-700 leading-relaxed">
                File Excel dilengkapi penataan header kolom otomatis, auto-width, dan format mata uang Rupiah.
              </p>
            </div>
          </div>

          <button
            onClick={handleDownloadProductsExcel}
            disabled={downloadingExcel}
            className="w-full py-3.5 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-md transition flex items-center justify-center space-x-2"
          >
            <Download className="w-4 h-4" />
            <span>{downloadingExcel ? 'Membuat Spreadsheet...' : 'Download Master Produk (.XLSX)'}</span>
          </button>
        </div>
      </div>
    </div>
  );
}

