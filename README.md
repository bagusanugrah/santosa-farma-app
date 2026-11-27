# Apotek Santosa Farma — Sistem Kasir POS & Pemesanan Web

Sistem informasi apotek modern dan terintegrasi untuk **Apotek Santosa Farma** (Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat). Sistem ini menghubungkan **aplikasi kasir Android POS (Flutter)** dengan **portal pemesanan obat online pelanggan (Next.js 14)** menggunakan **Supabase Cloud (PostgreSQL, Realtime, dan Storage)** sebagai pusat data terpadu.

Branding, palet warna (*Medical Cyan / Teal* `#0891B2` / `#0E7490` & *Deep Navy* `#1E3A5F`), serta ikon aplikasi diselaraskan dengan identitas visual resmi Instagram [**@santosafarma**](https://instagram.com/santosafarma).

> [!TIP]
> Untuk dokumentasi teknis mendalam (skema tabel lengkap, daftar endpoint API, arsitektur state/provider, alur bisnis, dan panduan AI handoff), baca [**DOCUMENTATION.md**](DOCUMENTATION.md).

---

## 🏛️ Arsitektur Proyek

```text
apotek-santosa-farma/
├── android/                                    # Aplikasi Android POS & Admin (Flutter)
│   ├── lib/
│   │   ├── config/                             # Theme @santosafarma & konfigurasi Supabase (.env)
│   │   ├── models/                             # Product, TransactionModel, TransactionItem, StoreSetting, UserModel
│   │   ├── providers/                          # AuthProvider, PosProvider, StoreProvider, WebOrdersProvider
│   │   ├── screens/                            # Login, POS, CashierTransactions, WebOrders, QrScanner, Products, Reports, Settings
│   │   ├── services/                           # SupabaseService, PrinterService, ExcelReportService, BackupService, AudioService
│   │   └── widgets/                            # AdaptiveScaffold, CartView, PaymentDialog, ProcessWebOrderDialog, ReceiptDialog
│   ├── .env.example                            # Template kredensial Supabase Android
│   └── pubspec.yaml
│
├── web-supabase/                               # Portal Web Pelanggan (Next.js 14 App Router)
│   ├── src/
│   │   ├── app/                                # Katalog (/), Checkout, Orders, Orders/[invoice], Profile, Auth & API Routes
│   │   ├── components/                         # Header, MobileBottomNav, ProductCard, CartDrawer, OtpModal, QrPickupModal
│   │   ├── context/                            # AuthContext, CartContext, StoreStatusContext
│   │   └── lib/                                # Supabase client/admin, JWT auth, settings, notifications, Midtrans Snap
│   ├── tailwind.config.js                      # Tailwind theme resmi Santosa Farma
│   └── package.json
│
├── DOCUMENTATION.md                            # Dokumentasi teknis menyeluruh (fitur, API, DB, alur bisnis)
└── supabase_schema.sql                         # Skema all-in-one PostgreSQL, RLS, Realtime, Storage & Seeder awal
```

---

## 🔐 Pemisahan Hak Akses & Keamanan Sesi

> [!IMPORTANT]
> Demi keamanan operasional apotek, kredensial login **tidak ditampilkan di layar aplikasi**. Sesi Android juga dilindungi dengan `allowBackup="false"`, `data_extraction_rules.xml` (mencegah auto-restore sesi saat install ulang APK), serta validasi sesi *fail-closed* ke server sebelum membuka dashboard.

| Tipe Akun | Role | Username / Kontak | Password Default | Hak Akses & Ruang Lingkup |
|---|---|---|---|---|
| **Super Admin** | `super_admin` | `admin` | `password123` | **Manajemen Apotek**: Kelola katalog obat & foto produk, pantau Laporan Penjualan gabungan (Read-Only) + ekspor Excel 3 sheet, atur Integrasi Gateway (Fonnte WA, SMTP Email, Midtrans), Backup/Restore ZIP + gambar, pembersihan storage *orphan*, Ubah Password, dan Factory Reset. |
| **Kasir Toko** | `admin_kasir` | `kasir` | `password123` | **Pelayanan Transaksi**: Kasir POS (Tunai/QRIS), Riwayat Transaksi Kasir Toko realtime, Pesanan Web Pelanggan + Edit Item (`Bayar di Apotek`), Scan QR Pengambilan Obat, Cetak/Bagikan Struk PDF, Sakelar Buka/Tutup Apotek & Pesanan Online, serta Ubah Password. *(Menu Kelola Obat, Laporan, Integrasi Gateway, Backup/Restore & Reset disembunyikan)* |
| **Customer Web** | `customer` | `081234567890` / `siti@example.com` | `password123` | Pendaftaran/login mandiri via web dengan verifikasi OTP WhatsApp/Email, belanja katalog, pembayaran online/apotek, pantau pesanan & QR pengambilan. |

---

## ✨ Fitur-Fitur Utama

### 1. Aplikasi Android POS & Admin (`android/`)

- **Tata Letak Responsif & Adaptif (`AdaptiveScaffold`)**:
  - Menyesuaikan otomatis antara tampilan smartphone (`NavigationBar`) dan tablet/layar lebar (`NavigationRail` & layout split POS).
- **Kasir POS & Pembayaran (`PosScreen`, `PaymentDialog`)**:
  - Pencarian cepat & filter kategori obat dengan indikator stok realtime.
  - **Pembayaran Tunai**: tombol nominal uang cepat (*quick cash*) dan perhitungan kembalian otomatis.
  - **Pembayaran QRIS Dinamis (Midtrans Core API v2)**: otomatis aktif jika kredensial Midtrans valid; menghasilkan QRIS langsung, *auto-polling* status pembayaran, tombol **Download QRIS**, serta **auto-cancel** transaksi ke Midtrans jika dialog ditutup atau kasir kembali ke tab Tunai sebelum dibayar.
- **Riwayat Transaksi Kasir Toko (`CashierTransactionsScreen`)**:
  - Memantau seluruh transaksi kanal `toko` secara realtime dengan filter rentang waktu, filter metode bayar (Tunai / QRIS), pencarian invoice/obat, ringkasan omzet, dan cetak ulang struk.
- **Pesanan Web Pelanggan & Scan QR (`WebOrdersScreen`, `QrScannerScreen`, `ProcessWebOrderDialog`)**:
  - **Notifikasi Realtime**: memutar bunyi lonceng (*chime*) seketika saat ada pesanan online masuk melalui Supabase Realtime.
  - **Filter & Pencarian Lengkap**: tab status (`Semua`, `Belum Dibayar`, `Siap Diambil`, `Selesai`) beserta pencarian berdasarkan nomor invoice, nama pelanggan, nomor HP, atau nama obat, plus tombol chat WhatsApp dan pembatalan permanen pesanan.
  - **Edit & Proses Pesanan "Bayar di Apotek" (`ProcessWebOrderDialog`)**: kasir dapat mengubah qty (*stepper*), menghapus item yang kosong, atau menambah obat baru sebelum menerima pembayaran (Tunai/QRIS) dan memotong stok aktual.
  - **Scan QR Kamera & Input Manual (`QrScannerScreen`)**: scanner terintegrasi (`mobile_scanner`) dengan kontrol senter (*torch*) dan input manual nomor invoice/token QR.
- **Struk Digital & PDF 80mm (`ReceiptDialog`, `PrinterService`)**:
  - Pratinjau struk digital dan ekspor/cetak PDF format roll thermal **80mm** (`pdf` + `printing` + `share_plus`).
- **Kelola Obat & Foto Storage (`ProductsScreen`, `ProductFormScreen`)**:
  - CRUD produk lengkap dengan unggah foto dari kamera/galeri ke Supabase Storage bucket `products` dan pembersihan otomatis gambar lama saat foto diubah atau produk dihapus.
- **Laporan Penjualan & Ekspor Excel Profesional (`ReportsScreen`, `ExcelReportService`)**:
  - Analisis omzet gabungan kanal **Kasir Toko** dan **Pesanan Web** dengan filter rentang waktu & kanal.
  - Ekspor laporan **Excel (`.xlsx`) 3 sheet terstruktur**: `Ringkasan & Transaksi`, `Rincian Obat Terjual`, dan `Produk Terlaris`.
- **Pengaturan Toko, Integrasi, Backup ZIP & Reset (`SettingsScreen`, `BackupService`)**:
  - Sakelar **Buka/Tutup Apotek** dan **Penerimaan Pesanan Online** (khusus Kasir) yang tersinkron realtime ke website.
  - Konfigurasi **Fonnte WhatsApp**, **SMTP Email**, dan **Midtrans** (lengkap dengan **Test Koneksi Midtrans**) yang tersimpan di `store_settings`.
  - **Backup & Restore ZIP**: mengemas seluruh data tabel + file foto produk (`images/`) ke arsip `.zip` untuk dibagikan/disimpan, serta saat restore otomatis menghapus seluruh gambar lama di storage dan menggantinya dengan gambar dari file backup.
  - **Factory Reset** untuk Super Admin (beserta pembersihan otomatis storage gambar).

### 2. Portal Web Pelanggan (`web-supabase/`)

- **Katalog Obat Digital & Status Apotek Realtime (`/`)**:
  - Pencarian instan, filter kategori, pengurutan, pagination, serta sinkronisasi status buka/tutup apotek dan status pesanan online secara realtime.
- **Autentikasi Pelanggan & Verifikasi OTP**:
  - Registrasi, login (No HP atau Email), tambah/ubah kontak di halaman `/profile` (wajib verifikasi OTP ulang), serta lupa/reset password melalui OTP **WhatsApp (Fonnte)** atau **Email (SMTP)**.
- **Opsi Pembayaran Fleksibel (`/checkout`)**:
  - **Bayar di Apotek (Kasir)**: buat pesanan langsung tanpa gateway online dan bayar di kasir (Tunai / QRIS).
  - **Bayar Online (Midtrans Snap)**: pembayaran via QRIS, e-wallet, atau Virtual Account Bank (otomatis aktif jika kredensial Midtrans terkonfigurasi di `store_settings`).
- **Halaman Pesanan Saya (`/orders` & `/orders/[invoice]`)**:
  - Sinkronisasi status pesanan realtime dengan tab filter, tombol **Bayar Sekarang** untuk transaksi `pending`, persistensi instruksi & salin nomor **Virtual Account (VA)**, verifikasi pembayaran manual ke Midtrans, serta opsi batalkan pesanan.
- **QR Code & Slip Pengambilan Cetak (`QrPickupModal`)**:
  - QR Code pengambilan obat lengkap dengan tampilan cetak khusus (`#pickup-print-slip`) satu halaman penuh untuk ditunjukkan ke kasir.

---

## 🚀 Panduan Menjalankan & Membangun

### A. Setup Database & Storage Supabase

1. Buka project dashboard di [Supabase](https://supabase.com).
2. Cukup jalankan **1 file saja**: salin & jalankan seluruh isi [`supabase_schema.sql`](supabase_schema.sql) di menu **SQL Editor** (sudah mencakup seluruh tabel, kolom integrasi Fonnte/SMTP/Midtrans, Realtime, RLS, seeder awal, dan Storage bucket `products`).

---

### B. Web Pelanggan (`web-supabase/`)

1. **Instalasi Dependensi**:
   ```bash
   cd web-supabase
   npm install
   ```

2. **File Environment (`.env.local`)**:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
   JWT_SECRET=your-random-jwt-secret

   # Opsional fallback (pengaturan utama dibaca dari tabel store_settings via app Android Admin)
   NEXT_PUBLIC_MIDTRANS_CLIENT_KEY=
   MIDTRANS_SERVER_KEY=
   MIDTRANS_IS_PRODUCTION=false
   WA_GATEWAY_TOKEN=
   WA_GATEWAY_URL=https://api.fonnte.com/send
   MAIL_HOST=smtp.gmail.com
   MAIL_PORT=587
   MAIL_USERNAME=
   MAIL_PASSWORD=
   MAIL_FROM_NAME="Apotek Santosa Farma"
   ```

3. **Jalankan Development Server**:
   ```bash
   npm run dev
   # Akses di browser: http://localhost:3000
   ```

4. **Build untuk Produksi (Vercel / Node)**:
   ```bash
   npm run build
   ```

---

### C. Aplikasi Android POS (`android/`)

1. **Persiapan Flutter**:
   Pastikan Flutter SDK (versi >= 3.24) dan Android SDK telah terpasang:
   ```bash
   cd android
   flutter pub get
   ```

2. **Konfigurasi Environment (`.env`)**:
   Salin template `.env.example` menjadi `.env` di dalam folder `android/`:
   ```bash
   cp .env.example .env
   ```
   > [!IMPORTANT]
   > File `.env` otomatis diabaikan oleh Git (`.gitignore`) agar kredensial Supabase tidak bocor ke repositori.

   Variabel di dalam `android/.env`:
   | Variabel | Deskripsi | Contoh Nilai |
   |---|---|---|
   | `SUPABASE_URL` | URL project Supabase Cloud Anda | `https://your-project.supabase.co` |
   | `SUPABASE_ANON_KEY` | Supabase Anon / Publishable Key | `sb_publishable_...` atau `eyJhbGciOi...` |
   | `SUPABASE_PRODUCTS_BUCKET` | *(Opsional)* Nama bucket storage foto obat | `products` |

3. **Jalankan Aplikasi (Mode Debug)**:
   ```bash
   flutter run --dart-define-from-file=.env
   ```

4. **Build APK Rilis (Production)**:
   ```bash
   flutter build apk --release --dart-define-from-file=.env
   ```
   Output APK: `android/build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 Lisensi & Hak Cipta

Hak Cipta © 2026 **Apotek Santosa Farma**. Semua hak dilindungi undang-undang.
Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat.
Instagram: [@santosafarma](https://instagram.com/santosafarma)
