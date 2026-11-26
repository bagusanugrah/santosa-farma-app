# Dokumentasi Teknis Lengkap — Sistem Informasi Apotek Santosa Farma

> **Tujuan Dokumen Ini:** Memberikan peta teknis yang lengkap, akurat, dan terstruktur mengenai arsitektur, database, fitur, alur bisnis, autentikasi, serta integrasi sistem **Apotek Santosa Farma** (Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat) agar developer maupun AI assistant baru dapat langsung memahami proyek tanpa harus menelusuri ulang dari nol.

---

## 1. Gambaran Umum & Arsitektur Sistem

Proyek ini terdiri dari **2 aplikasi utama** yang terhubung ke **1 pusat data Supabase Cloud (PostgreSQL + Realtime + Storage)**:

1. **`android/` — Aplikasi Kasir & Manajemen Apotek (Flutter)**
   - Dipakai oleh **Kasir Toko** (`admin_kasir`) dan **Super Admin** (`super_admin`) di perangkat Android (smartphone maupun tablet).
   - Berkomunikasi langsung dengan Supabase PostgreSQL, Supabase Storage, dan Midtrans Core API (untuk QRIS dinamis di kasir).
2. **`web-supabase/` — Portal Pemesanan Obat Online Pelanggan (Next.js 14 App Router)**
   - Dipakai oleh **Pelanggan** (`customer`) untuk melihat katalog obat, login/registrasi dengan OTP, memesan obat secara online, membayar via Midtrans Snap atau Bayar di Apotek, dan mendapatkan QR Code pengambilan obat.
   - Menggunakan Next.js API Routes sebagai backend serverless (menggunakan `supabaseAdmin` / Service Role Key) untuk autentikasi JWT, pengiriman OTP WhatsApp/Email, Midtrans Snap/Webhook, dan verifikasi stok.

> [!NOTE]
> Meskipun file `prompt-aplikasi-apotek-santosa-farma.md` di root sempat merujuk konsep awal (Laravel/Desktop/React Native), implementasi aktual yang aktif dan berjalan di repositori ini adalah **Flutter (`android/`) + Next.js (`web-supabase/`) + Supabase Cloud**.

### Diagram Keterhubungan Sistem

```text
+----------------------------------+         +----------------------------------+
|   Portal Web Pelanggan           |         |   Aplikasi Android POS           |
|   (web-supabase / Next.js 14)    |         |   (android / Flutter)            |
+----------------+-----------------+         +----------------+-----------------+
                 |                                            |
   Next.js API Routes (JWT, OTP,               Direct Supabase Client +
   Midtrans Snap & Webhook, Checkout)          Realtime Subscriptions
                 |                                            |
                 +---------------------+----------------------+
                                       v
                 +--------------------------------------------+
                 |              SUPABASE CLOUD                |
                 |  - PostgreSQL (9 tabel + Realtime)         |
                 |  - Storage Bucket: 'products' (foto obat)  |
                 +---------------------+----------------------+
                                       |
         +-----------------------------+-----------------------------+
         v                             v                             v
+------------------+         +------------------+         +------------------+
| Midtrans Gateway |         | Fonnte WhatsApp  |         | Gmail / SMTP     |
| (Snap & QRIS v2) |         | (OTP Pelanggan)  |         | (OTP Email)      |
+------------------+         +------------------+         +------------------+
```

---

## 2. Struktur Direktori Proyek

```text
apotek-santosa-farma/
├── DOCUMENTATION.md                              # Dokumentasi teknis menyeluruh (file ini)
├── README.md                                     # Ringkasan awal & panduan setup cepat
├── supabase_schema.sql                           # Skema lengkap DB PostgreSQL, RLS, Realtime, Seeder
├── supabase_migration_integration_settings.sql   # Migrasi kolom Fonnte, SMTP, Midtrans di store_settings
├── supabase_migration_storage_rls.sql            # Migrasi bucket & RLS Storage 'products'
│
├── android/                                      # Aplikasi Android POS & Admin (Flutter)
│   ├── .env.example                              # Template SUPABASE_URL, SUPABASE_ANON_KEY, BUCKET
│   ├── pubspec.yaml                              # Dependensi Flutter (supabase_flutter, provider, pdf, excel, dll.)
│   ├── android/app/src/main/
│   │   ├── AndroidManifest.xml                   # Permissions & allowBackup="false"
│   │   └── res/xml/data_extraction_rules.xml     # Blokir cloud backup & device transfer sesi login
│   └── lib/
│       ├── main.dart                             # Entry point, ErrorWidget fallback, Auth/Provider tree isolation
│       ├── config/
│       │   ├── supabase_config.dart              # Membaca --dart-define-from-file=.env & URL gambar produk
│       │   └── theme.dart                        # Tema Material 3 Cyan/Teal & Deep Navy (@santosafarma)
│       ├── models/
│       │   ├── product.dart                      # Model Product
│       │   ├── store_setting.dart                # Model StoreSetting & UserModel (staff)
│       │   ├── transaction.dart                  # Model TransactionModel
│       │   └── transaction_item.dart             # Model TransactionItem
│       ├── providers/
│       │   ├── auth_provider.dart                # Sesi staff, validasi server, fail-closed login guard
│       │   ├── pos_provider.dart                 # Katalog POS, filter kategori, keranjang, checkout
│       │   ├── store_provider.dart               # Status buka/tutup toko, status online order, Midtrans check
│       │   └── web_orders_provider.dart          # Pesanan online realtime + audio chime notifikasi
│       ├── screens/
│       │   ├── login_screen.dart                 # Form login username/password staff
│       │   ├── main_navigation_screen.dart       # Routing tab berdasarkan role (Admin vs Kasir) + auth guard
│       │   ├── pos_screen.dart                   # Layar Kasir POS (grid obat + keranjang responsif)
│       │   ├── cashier_transactions_screen.dart  # Riwayat transaksi kasir toko realtime + filter
│       │   ├── web_orders_screen.dart            # Daftar pesanan web (tab status, pencarian, aksi kasir)
│       │   ├── qr_scanner_screen.dart            # Scanner QR pengambilan/pembayaran pesanan web
│       │   ├── products_screen.dart              # Kelola katalog obat (Super Admin)
│       │   ├── product_form_screen.dart          # Form tambah/ubah obat + upload foto (kamera/galeri)
│       │   ├── reports_screen.dart               # Laporan penjualan multi-kanal & export Excel (Super Admin)
│       │   └── settings_screen.dart              # Profil, status toko, ubah password, integrasi, backup/reset
│       ├── services/
│       │   ├── supabase_service.dart             # Seluruh query DB, storage, Midtrans Core API, backup/reset
│       │   ├── printer_service.dart              # Generator PDF struk 80mm & cetak/bagikan
│       │   ├── excel_report_service.dart         # Generator laporan Excel (.xlsx) 3 sheet terstruktur
│       │   ├── backup_service.dart               # Export/Restore ZIP (JSON database + folder images/)
│       │   └── audio_service.dart                # Pemutar bunyi lonceng (chime) pesanan online baru
│       └── widgets/
│           ├── adaptive_scaffold.dart            # Layout adaptif Smartphone (BottomNav) vs Tablet (NavRail)
│           ├── product_card.dart                 # Kartu produk di grid POS
│           ├── cart_view.dart                    # Panel keranjang kasir + tombol bayar
│           ├── quick_cash_buttons.dart           # Tombol nominal uang cepat (Rp 10rb, 20rb, 50rb, 100rb, Pas)
│           ├── payment_dialog.dart               # Dialog pembayaran Tunai & QRIS Midtrans (auto-poll & cancel)
│           ├── process_web_order_dialog.dart     # Dialog proses/edit item pesanan web "Bayar di Apotek"
│           └── receipt_dialog.dart               # Pratinjau struk digital + cetak PDF / bagikan
│
└── web-supabase/                                 # Portal Web Pelanggan (Next.js 14)
    ├── package.json
    ├── tailwind.config.js                        # Konfigurasi warna brand Santosa Farma
    └── src/
        ├── context/
        │   ├── AuthContext.tsx                   # State login customer (JWT + localStorage)
        │   ├── CartContext.tsx                   # Keranjang belanja web (persistensi lokal)
        │   └── StoreStatusContext.tsx            # Status toko & Midtrans realtime dari store_settings
        ├── lib/
        │   ├── supabase.ts                       # Client `supabase` (anon) & `supabaseAdmin` (service role)
        │   ├── server-auth.ts                    # JWT sign/verify (30 hari), bcryptjs, normalisasi HP 62/0/+62
        │   ├── settings.ts                       # Reader integrasi dari `store_settings` + cache 1 menit + fallback env
        │   ├── notifications.ts                  # Pengirim OTP WhatsApp (Fonnte) & Email (Nodemailer SMTP)
        │   ├── midtrans.ts                       # Loader dinamis script Midtrans Snap (Sandbox/Production)
        │   └── api.ts                            # Helper fetch produk, status toko, tipe data, format URL gambar
        ├── components/
        │   ├── Header.tsx                        # Navbar atas, badge keranjang, menu profil/pesanan
        │   ├── MobileBottomNav.tsx               # Navigasi bawah untuk tampilan mobile web
        │   ├── StoreClosedBanner.tsx             # Banner status toko tutup / online orders nonaktif
        │   ├── ProductCard.tsx                   # Kartu obat di katalog web
        │   ├── CartDrawer.tsx                    # Drawer keranjang belanja slide-over
        │   ├── OtpModal.tsx                      # Modal input OTP 6 digit + kirim ulang OTP
        │   └── QrPickupModal.tsx                 # Modal QR Code pengambilan + slip cetak (`#pickup-print-slip`)
        └── app/
            ├── page.tsx                          # Halaman utama Katalog Obat (search, kategori, sort, pagination)
            ├── login/page.tsx                    # Login pelanggan (No HP atau Email + password)
            ├── register/page.tsx                 # Registrasi pelanggan + verifikasi OTP
            ├── forgot-password/page.tsx          # Permintaan reset password via OTP
            ├── reset-password/page.tsx           # Set password baru menggunakan token reset
            ├── profile/page.tsx                  # Profil pelanggan, tambah/ubah kontak (OTP), ganti password
            ├── checkout/page.tsx                 # Checkout (Bayar di Apotek vs Midtrans Snap)
            ├── orders/page.tsx                   # Daftar pesanan saya + tombol Bayar Sekarang + info VA
            ├── orders/[invoice]/page.tsx         # Detail pesanan per invoice + QR Code + verifikasi/batal
            └── api/                              # Endpoint backend Next.js (lihat Bagian 6)
```

---

## 3. Skema Database & Storage Supabase

Definisi utama ada di `supabase_schema.sql`, ditambah 2 file migrasi (`supabase_migration_integration_settings.sql` dan `supabase_migration_storage_rls.sql`).

### 3.1 Daftar Tabel PostgreSQL (`public`)

| Tabel | Fungsi Utama | Kolom Kunci & Keterangan |
|---|---|---|
| `users` | Akun staff internal (Kasir & Super Admin) | `id`, `name`, `username` (UNIQUE), `password` (bcrypt), `role` (`super_admin` atau `admin_kasir`). Tidak ada self-register untuk staff. |
| `customers` | Akun pelanggan portal web | `id`, `name`, `phone` (UNIQUE), `phone_verified_at`, `email` (UNIQUE), `email_verified_at`, `password` (bcrypt). |
| `otp_codes` | Kode OTP verifikasi kontak | `id`, `customer_id`, `type` (`phone` / `email`), `target`, `code` (6 digit), `expires_at` (5 menit), `verified_at`. |
| `password_resets` | Token reset password pelanggan | `id`, `customer_id`, `target`, `token` (64 char), `type`, `expires_at`, `used_at`. |
| `products` | Katalog produk / obat apotek | `id`, `name`, `category`, `price` (`NUMERIC(12,2)`), `stock` (`INT`), `description`, `image` (nama file di bucket `products` atau full URL). |
| `store_settings` | Pengaturan global toko & gateway (singleton `id = 1`) | `is_open`, `online_orders_enabled`, `last_opened_at`, `last_closed_at`, `fonnte_token`, `fonnte_url`, `mail_host`, `mail_port`, `mail_username`, `mail_password`, `mail_from_name`, `midtrans_client_key`, `midtrans_server_key`, `midtrans_is_production`. |
| `transactions` | Header transaksi kasir fisik & pesanan online | `id`, `invoice_no` (UNIQUE, contoh `POS-YYYYMMDD-XXXX` atau `INV-...`), `channel` (`toko` / `online`), `customer_id`, `cashier_id`, `payment_method` (`tunai`, `qris`, `kartu`, `va`, `pharmacy`), `midtrans_order_id`, `midtrans_snap_token`, `midtrans_qris_url`, `midtrans_va_number`, `status`, `total`, `amount_paid`, `change_amount`, `qr_token` (UNIQUE), `paid_at`, `picked_up_at`. |
| `transaction_items` | Detail item obat per transaksi | `id`, `transaction_id` (`ON DELETE CASCADE`), `product_id` (`ON DELETE SET NULL`), `product_name`, `qty`, `price`, `subtotal`. |
| `receipts` | Arsip path struk digital | `id`, `transaction_id`, `file_path`. |

### 3.2 Siklus Status Transaksi (`transactions.status`)

- **Kanal `toko` (POS Kasir langsung):** langsung berstatus `selesai` saat checkout di Android POS.
- **Kanal `online` (Pesanan Web):**
  - `pending`: pesanan baru dibuat (baik metode **Bayar di Apotek** maupun **Midtrans** yang belum dibayar).
  - `paid`: pembayaran online via Midtrans sudah terkonfirmasi (*settlement/capture*), obat siap diambil di apotek (stok sudah dipotong).
  - `diambil`: pelanggan sudah mengambil pesanan yang statusnya `paid` dan kasir telah memindai QR Code (`verifyAndPickupOrder`).
  - `selesai`: pesanan web "Bayar di Apotek" yang telah diproses, diedit (jika perlu), dan dibayar di kasir via `ProcessWebOrderDialog`.
  - `expired` / `gagal` / `dibatalkan`: pembayaran kadaluarsa, gagal, atau dibatalkan. (Catatan: pembatalan pesanan web di kasir atau customer tertentu menghapus permanen record `transaction_items` dan `transactions`).

### 3.3 Realtime & Storage

- **Supabase Realtime (`supabase_realtime` publication):** diaktifkan untuk tabel `transactions`, `store_settings`, dan `products`.
- **Supabase Storage (`products` bucket):**
  - Bucket publik dengan batas ukuran file **5 MB** (`5242880` bytes) dan MIME yang diizinkan: `image/jpeg`, `image/png`, `image/webp`, `image/jpg`, `image/gif`.
  - Saat produk dihapus atau fotonya diganti di Android POS, aplikasi otomatis memeriksa apakah gambar lama masih dipakai produk lain; jika tidak, file gambar lama ikut dihapus dari Storage (`deleteProductImage`).

> [!WARNING]
> **Catatan Keamanan RLS Saat Ini:** Pada `supabase_schema.sql`, kebijakan RLS untuk `anon` masih diset permisif (`USING (true) WITH CHECK (true)`) karena aplikasi Android POS berkomunikasi langsung menggunakan `SUPABASE_ANON_KEY` dan login tabel `users` kustom (bukan Supabase Auth JWT). Jangan aktifkan RLS ketat tanpa menyediakan mekanisme auth/RPC yang sesuai untuk aplikasi Android.

---

## 4. Fitur & Modul Aplikasi Android POS (`android/`)

### 4.1 Autentikasi, Keamanan Sesi, & Role-Based Access Control (RBAC)

- **Login Staff (`LoginScreen` -> `AuthProvider.login` -> `SupabaseService.loginStaff`):**
  - Staff login menggunakan `username` dan `password` terhadap tabel `users`.
  - Mendukung verifikasi hash BCrypt (`$2a$`, `$2b$`, `$2y$`) melalui package `bcrypt`. *(Terdapat juga fallback pengecekan plaintext / default `'password123'` & `'admin123'` di `loginStaff` untuk keperluan seeder awal).*
- **Pengamanan Sesi & Anti-Bypass saat Install (`AuthProvider` & `AndroidManifest.xml`):**
  - `AndroidManifest.xml` menonaktifkan Android Auto Backup dan transfer perangkat:
    - `android:allowBackup="false"`
    - `android:fullBackupContent="false"`
    - `android:dataExtractionRules="@xml/data_extraction_rules"` (mengecualikan `sharedpref`, `database`, `file`, `root` dari cloud backup & device transfer).
  - `AuthProvider` menggunakan key sesi `santosa_pos_session_v2` dan otomatis menghapus key lama `santosa_pos_user`.
  - Saat aplikasi dibuka (`_loadUserSession`), sesi lokal **tidak langsung dipercaya**: sistem memvalidasi `id > 0`, `username` tidak kosong, `role` valid, lalu memanggil `SupabaseService.verifyStaffSession` ke tabel `users` (timeout 6 detik). Jika gagal/offline/akun dihapus (*fail-closed*), user wajib login ulang.
  - Pada `main.dart` (`SantosaPosApp`), `StoreProvider`, `PosProvider`, dan `WebOrdersProvider` hanya diinisialisasi setelah `auth.isAuthenticated && auth.currentUser != null`, dan otomatis ter-dispose saat `logout()`.
  - `MainNavigationScreen` memiliki guard tambahan di `build()` untuk mengarahkan ke `LoginScreen` jika belum terautentikasi.

- **Pemisahan Hak Akses UI (`MainNavigationScreen` & `AdaptiveScaffold`):**
  - **Super Admin (`role: 'super_admin'` atau `'admin'`):**
    1. **Katalog & Kelola Obat** (`ProductsScreen` + `ProductFormScreen`) — tambah, edit, hapus obat, upload foto (kamera/galeri).
    2. **Laporan Penjualan (Read-Only)** (`ReportsScreen`) — analitik omzet & export Excel `.xlsx`.
    3. **Pengaturan Apotek & Sistem** (`SettingsScreen`) — profil, ubah password, konfigurasi integrasi (Fonnte WA, SMTP Email, Midtrans), Backup/Restore ZIP, Bersihkan Gambar Orphan Storage, dan Factory Reset.
  - **Kasir Toko (`role: 'admin_kasir'`):**
    1. **Kasir POS Apotek** (`PosScreen`) — transaksi penjualan toko.
    2. **Transaksi Kasir (Toko)** (`CashierTransactionsScreen`) — riwayat & filter transaksi kanal `toko`.
    3. **Pesanan Web Pelanggan** (`WebOrdersScreen`) — daftar pesanan online realtime dengan badge jumlah pesanan siap ambil (`pendingPickupCount`).
    4. **Pengaturan & Akun Kasir** (`SettingsScreen`) — profil, sakelar **Status Buka/Tutup Apotek** & **Penerimaan Pesanan Online**, serta ubah password kasir. *(Menu Kelola Obat, Laporan, Integrasi Gateway, Backup/Restore, dan Factory Reset disembunyikan dari Kasir).*
  - **Tombol Scan QR di AppBar** hanya tampil untuk Kasir Toko.

### 4.2 Tata Letak Adaptif (`AdaptiveScaffold`)

- **Tablet / Layar Lebar (`width >= 800px`):** memakai `NavigationRail` di sisi kiri, header AppBar dengan logo resmi & badge role (`ADMIN` / `KASIR`), serta tampilan split grid + keranjang samping pada `PosScreen`.
- **Smartphone (`width < 800px`):** memakai `NavigationBar` di bawah layar, serta tombol/sheet keranjang di bagian bawah pada `PosScreen`.

### 4.3 Fitur Kasir POS & Pembayaran (`PosScreen`, `CartView`, `PaymentDialog`)

- **Pencarian & Filter Kategori:** pencarian nama obat secara instan + chip kategori (`Semua`, `Antibiotik`, `Analgesik`, `Flu & Batuk`, `Pencernaan`, `P3K`, `Vitamin`, `Daya Tahan Tubuh`, `Minyak Angin`, `Obat Cacing`).
- **Keranjang Belanja (`PosProvider`):** validasi stok maksimum, tambah/kurangi qty, hapus item, hitung `grandTotal`.
- **Pembayaran Tunai (`PaymentDialog` Tab Tunai):**
  - Dilengkapi `QuickCashButtons` untuk nominal cepat dan hitung kembalian otomatis.
- **Pembayaran QRIS Dinamis (`PaymentDialog` Tab QRIS):**
  - Tab QRIS hanya aktif jika `StoreProvider.isMidtransValid` bernilai `true` (kredensial terverifikasi ke Midtrans API).
  - Saat tab QRIS dibuka, aplikasi memanggil Midtrans Core API `POST /v2/charge` (`payment_type: 'qris'`, acquirer `'gopay'`).
  - Polling status otomatis (`checkMidtransStatus`) setiap beberapa detik dan tombol cek manual.
  - Fitur **Download QRIS** untuk menyimpan/membagikan gambar QRIS.
  - **Auto-Cancel:** jika dialog pembayaran ditutup atau kasir berpindah kembali ke tab Tunai sebelum QRIS dibayar, transaksi QRIS di Midtrans otomatis dibatalkan (`cancelMidtransTransaction`).
- **Penyelesaian & Struk (`ReceiptDialog` & `PrinterService`):**
  - Membuat nomor invoice `POS-YYYYMMDD-XXXX`, menyimpan ke `transactions` & `transaction_items`, dan otomatis memotong `products.stock`.
  - Pratinjau struk digital + generate PDF format thermal **80mm** (`PdfPageFormat.roll80`) dengan font Poppins untuk dicetak atau dibagikan via `printing` / `share_plus`.

### 4.4 Pesanan Web Realtime, Scan QR, & Edit Pesanan (`WebOrdersProvider`, `WebOrdersScreen`, `QrScannerScreen`, `ProcessWebOrderDialog`)

- **Notifikasi Realtime (`WebOrdersProvider`):** berlangganan perubahan tabel `transactions` (`channel == 'online'`) dan memutar bunyi lonceng (`AudioService.playOrderChime()`) saat pesanan online masuk/berubah.
- **Tab Filter & Pencarian (`WebOrdersScreen`):**
  - 4 Tab: `Semua`, `Belum Dibayar` (`pending`), `Siap Diambil` (`paid`), `Selesai` (`diambil` / `selesai`).
  - Search bar mendukung pencarian berdasarkan nomor invoice, nama pelanggan, nomor HP pelanggan (normalisasi digit), maupun nama obat di dalam pesanan.
  - Tombol kontak WhatsApp pelanggan langsung (`url_launcher`) & tombol hapus/batalkan pesanan permanen.
- **Scan QR & Input Manual (`QrScannerScreen`):**
  - Menggunakan kamera `mobile_scanner` (dengan kontrol *torch*/flash) atau input manual token QR / nomor invoice (`INV-...`).
  - Penanganan cerdas berdasarkan status order:
    - Jika `diambil` / `selesai` -> tampilkan info sudah diambil + tombol lihat struk.
    - Jika `pending` (Bayar di Apotek) -> langsung buka **`ProcessWebOrderDialog`**.
    - Jika `paid` (Lunas Midtrans) -> konfirmasi serah terima & ubah status menjadi `diambil` (`picked_up_at`).
- **Proses & Edit Pesanan Web di Kasir (`ProcessWebOrderDialog`):**
  - Khusus pesanan online `pending` (Bayar di Apotek), kasir bisa **mengubah qty obat**, **menghapus obat** yang kosong/batal, atau **menambahkan obat baru** langsung dari katalog POS.
  - Pembayaran diproses via `PaymentDialog` (Tunai / QRIS Midtrans), lalu `SupabaseService.completeWebOrderAtPos` mengganti `transaction_items`, memotong stok produk aktual, dan mengubah status transaksi menjadi `selesai`.
  - Tersedia opsi batalkan & hapus pesanan permanen (`cancelWebOrder`).

### 4.5 Laporan Penjualan & Ekspor Excel (`ReportsScreen`, `ExcelReportService`)

- Filter rentang waktu (`Hari Ini`, `7 Hari`, `30 Hari`, `Semua`) dan kanal (`Semua`, `Kasir Toko`, `Pesanan Web`).
- Menampilkan ringkasan omzet total, omzet per kanal, jumlah transaksi, serta metode bayar (Tunai vs QRIS).
- **Ekspor Laporan Excel (`.xlsx`) Profesional 3 Sheet** (`ExcelReportService`):
  1. `Ringkasan & Transaksi`: ringkasan metrik KPI (total omzet, omzet kasir vs web, tunai vs QRIS, AOV) + daftar lengkap transaksi.
  2. `Rincian Obat Terjual`: breakdown setiap item obat yang terjual per transaksi.
  3. `Produk Terlaris`: ranking produk terlaris berdasarkan jumlah terjual dan kontribusi pendapatan.
  - File langsung dibagikan/disimpan melalui `share_plus`.

### 4.6 Manajemen Gateway, Backup ZIP + Gambar, Cleanup Storage, & Factory Reset (`SettingsScreen`, `BackupService`)

- **Integrasi Gateway (disimpan ke `store_settings` id=1):**
  - WhatsApp Fonnte (`fonnte_token`, `fonnte_url`).
  - Email SMTP (`mail_host`, `mail_port`, `mail_username`, `mail_password`, `mail_from_name`).
  - Midtrans (`midtrans_client_key`, `midtrans_server_key`, `midtrans_is_production`) + tombol **Test Koneksi Midtrans**.
- **Backup & Restore ZIP (`BackupService`):**
  - **Backup:** Mengekspor tabel `products`, `transactions`, `transaction_items`, `store_settings`, dan `customers` ke file JSON, serta mengunduh seluruh foto produk aktif ke folder `images/` di dalam file `.zip` (`backup_santosa_farma_YYYYMMDD_HHmmss.zip`).
  - **Restore:** Menerima file `.zip` atau `.json`, mengunggah ulang file biner gambar ke Supabase Storage bucket `products` (`upsert: true`), melakukan `upsert` data ke seluruh tabel, dan menjalankan `cleanupOrphanProductImages()`.
- **Bersihkan Storage Gambar Orphan (`cleanupOrphanProductImages`):** membandingkan file di bucket `products` dengan kolom `products.image`, lalu menghapus file yang tidak terpakai oleh produk mana pun.
- **Factory Reset (`factoryReset`):** menghapus `transaction_items`, `transactions`, `otp_codes`, `password_resets`, mereset `store_settings`, mengisi ulang 12 produk seed standar, dan membersihkan gambar custom di storage.

---

## 5. Fitur & Modul Portal Web Pelanggan (`web-supabase/`)

### 5.1 Katalog Obat & Status Toko Realtime (`/` & `StoreStatusContext`)

- `StoreStatusContext` berlangganan realtime ke `store_settings` (id=1).
- Jika `is_open === false` (Apotek Tutup), halaman utama menampilkan layar pemberitahuan bahwa apotek sedang tutup dan pencarian/pemesanan dinonaktifkan sementara.
- Jika toko buka namun `online_orders_enabled === false`, pelanggan masih dapat melihat katalog tetapi checkout online dinonaktifkan (`StoreClosedBanner`).
- Fitur katalog (`src/app/page.tsx`): pencarian nama obat, filter kategori (`all`, `Analgesik`, `Antibiotik`, `Flu & Batuk`, `Herbal`, `Mata`, `Minyak Angin`, `Obat Cacing`, `P3K`, `Pencernaan`, `Vitamin`, `Daya Tahan Tubuh`), pengurutan, pagination, dan pemilihan jumlah item per halaman.
- Gambar produk dari URL eksternal/storage dapat diproksi melalui `/api/image-proxy` bila diperlukan.

### 5.2 Autentikasi Pelanggan, OTP, & Profil

- **JWT Customer (`src/lib/server-auth.ts`):**
  - Token ditandatangani dengan `JWT_SECRET` (berlaku **30 hari**) dan dikirim via header `Authorization: Bearer <token>`.
  - Pencarian nomor HP mendukung variasi format Indonesia (`08...`, `628...`, `+628...`) via `getPhoneVariants`.
- **Alur Akun Pelanggan:**
  - **Registrasi (`/register`):** input nama, no HP atau email, password -> buat record customer + generate OTP 6 digit (`otp_codes`, berlaku 5 menit) -> kirim via **WhatsApp Fonnte** atau **Email SMTP** (`src/lib/notifications.ts`) -> verifikasi di `OtpModal` -> aktifkan kontak & login otomatis.
  - **Login (`/login`):** login dengan nomor HP **atau** email + password (`bcryptjs`).
  - **Lupa & Reset Password (`/forgot-password`, `/reset-password`):** kirim OTP ke kontak terverifikasi -> verifikasi OTP -> buat token di `password_resets` -> atur password baru.
  - **Profil (`/profile`):** ubah nama, ubah password, atau tambah/ganti kontak (HP / email) yang **wajib diverifikasi OTP ulang** sebelum aktif.

### 5.3 Keranjang, Checkout, Pembayaran Midtrans, & QR Pengambilan

- **Keranjang (`CartContext` + `CartDrawer`):** simpan item di state/localStorage, ubah qty, lanjut ke `/checkout` (wajib login).
- **Checkout (`/checkout` -> `POST /api/transactions/checkout`):**
  - Memverifikasi `store_settings.is_open` dan `online_orders_enabled` di server, serta memeriksa stok aktual produk.
  - Dua metode pembayaran:
    1. **Bayar di Apotek (`pharmacy`):** membuat transaksi `status: 'pending'` + `qr_token` unik, langsung memunculkan **`QrPickupModal`** untuk ditunjukkan ke kasir. *(Stok belum dipotong sampai kasir memprosesnya di `ProcessWebOrderDialog`).*
    2. **Bayar Online via Midtrans Snap (`midtrans`):** aktif hanya jika `midtrans_client_key` dan `midtrans_server_key` valid. Membuat Snap Token di server, memuat `snap.js` (Sandbox/Production sesuai `midtrans_is_production`), dan membuka popup pembayaran Midtrans.
- **Manajemen Pesanan Pelanggan (`/orders` & `/orders/[invoice]`):**
  - Filter tab (`Semua`, `Belum Dibayar`, `Siap Diambil`, `Sudah Diambil`).
  - **Tombol "Bayar Sekarang" & Persistensi Virtual Account:** untuk pesanan Midtrans yang masih `pending`, halaman otomatis memanggil `/api/transactions/customer/pay-order` untuk mengambil ulang Snap Token serta detail VA / kode pembayaran agar tetap tampil dan bisa disalin pelanggan.
  - **Verifikasi Pembayaran Manual (`/api/transactions/verify-payment`):** mengecek langsung ke Midtrans Status API jika webhook belum masuk.
  - **Batalkan Pesanan (`/api/transactions/customer/cancel-order`):** membatalkan pesanan `pending`.
  - **QR Code Pengambilan & Slip Cetak (`QrPickupModal`):** menampilkan QR Code (`qr_token` / `invoice_no`) dan menyertakan stylesheet `@media print` khusus yang hanya mencetak elemen `#pickup-print-slip` secara rapi satu halaman penuh.

---

## 6. Daftar Lengkap Next.js API Routes (`web-supabase/src/app/api/`)

| Method & Endpoint | Auth | Fungsi |
|---|---|---|
| `POST /api/auth/customer/register` | Publik | Registrasi akun customer baru & kirim OTP awal |
| `POST /api/auth/customer/login` | Publik | Login customer dengan HP/Email & password, return JWT |
| `POST /api/auth/customer/verify-otp` | Publik | Verifikasi OTP 6 digit (registrasi, tambah kontak, reset password) |
| `POST /api/auth/customer/resend-otp` | Publik | Kirim ulang OTP ke WA/Email |
| `POST /api/auth/customer/add-contact` | Bearer JWT | Tambah/ubah nomor HP atau email di profil & kirim OTP verifikasi |
| `GET, PUT /api/auth/customer/profile` | Bearer JWT | Ambil atau perbarui profil (nama) customer |
| `POST /api/auth/customer/change-password` | Bearer JWT | Ganti password customer dari halaman profil |
| `POST /api/auth/customer/forgot-password` | Publik | Kirim OTP untuk permintaan reset password |
| `POST /api/auth/customer/reset-password` | Publik | Simpan password baru dengan token reset valid |
| `POST /api/transactions/checkout` | Bearer JWT | Validasi toko & stok, buat transaksi `online`, & generate Midtrans Snap jika dipilih |
| `POST /api/transactions/verify-payment` | Bearer JWT | Cek status transaksi ke Midtrans API & update `paid` + potong stok |
| `GET /api/transactions/customer/my-orders` | Bearer JWT | Ambil riwayat pesanan milik customer |
| `POST /api/transactions/customer/pay-order` | Bearer JWT | Ambil ulang `midtrans_snap_token` & detail VA/QRIS untuk pesanan `pending` |
| `POST /api/transactions/customer/cancel-order` | Bearer JWT | Batalkan pesanan `pending` milik customer |
| `POST /api/webhooks/midtrans` | Signature SHA-512 | Webhook notifikasi Midtrans (`settlement`/`capture`/`expire`/`cancel`), update status & potong stok |
| `GET /api/receipts/[id]/pdf` | Publik (by ID) | Render HTML struk transaksi siap cetak (`window.print()`) |
| `GET /api/image-proxy` | Publik | Proxy gambar produk dengan header cache & anti-ngrok warning |

---

## 7. Variabel Environment & Cara Build/Run

### 7.1 Aplikasi Android (`android/`)

Salin `android/.env.example` menjadi `android/.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-publishable-or-anon-key
SUPABASE_PRODUCTS_BUCKET=products
```

Perintah menjalankan & membangun APK (wajib menyertakan `--dart-define-from-file=.env` karena `SupabaseConfig` membaca `String.fromEnvironment`):

```bash
cd android
flutter pub get
flutter run --dart-define-from-file=.env
flutter build apk --release --dart-define-from-file=.env
```

Output APK berada di: `android/build/app/outputs/flutter-apk/app-release.apk`.

### 7.2 Portal Web (`web-supabase/`)

Buat `web-supabase/.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
JWT_SECRET=your-secret-key

# Opsional fallback jika belum diisi di menu Pengaturan Integrasi aplikasi Android (store_settings id=1):
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

Perintah menjalankan & build web:

```bash
cd web-supabase
npm install
npm run dev      # http://localhost:3000
npm run build
```

---

## 8. Panduan Penting untuk AI Assistant Berikutnya (AI Handoff Rules)

Jika Anda adalah AI coding assistant yang melanjutkan proyek ini, perhatikan aturan & fakta penting berikut:

1. **Konfigurasi Integrasi Berpusat di Database (`store_settings` row `id = 1`):**
   - Kredensial **Midtrans**, **Fonnte WhatsApp**, dan **SMTP Email** diatur secara dinamis oleh Super Admin melalui `SettingsScreen` di aplikasi Android dan disimpan ke tabel `store_settings`.
   - `web-supabase/src/lib/settings.ts` membaca dari `store_settings` (di-cache 60 detik) dan hanya memakai `.env` sebagai fallback. Jangan memutus alur pembacaan dari `store_settings`.
2. **Keamanan Login & Sesi Android POS:**
   - **Jangan** menghapus `android:allowBackup="false"`, `android:fullBackupContent="false"`, atau `data_extraction_rules.xml` dari `AndroidManifest.xml`, karena jika backup aktif, `SharedPreferences` akan ter-restore saat install ulang APK dan pengguna langsung masuk ke dashboard tanpa login.
   - `AuthProvider` menggunakan key `santosa_pos_session_v2` dan memverifikasi ulang sesi terhadap tabel `users` secara *fail-closed* sebelum membuka `MainNavigationScreen`.
3. **Perbedaan Metode Pembayaran & Stok antara Kasir vs Web:**
   - Di **POS Kasir (`toko`)** dan **Midtrans Web (`paid`)**, stok dikurangi saat pembayaran berhasil.
   - Di **Pesanan Web "Bayar di Apotek" (`payment_method = 'pharmacy'`, `status = 'pending'`)**, stok **belum** dikurangi saat checkout di web; stok baru dikurangi setelah kasir meninjau/mengedit item dan menyelesaikan pembayaran di `ProcessWebOrderDialog` (`completeWebOrderAtPos`).
4. **Identitas Visual & Bahasa:**
   - Seluruh teks UI berbahasa **Indonesia** formal/ramah apotek.
   - Warna utama menggunakan **Medical Cyan/Teal** (`#0891B2`, `#0E7490`) dan **Deep Navy** (`#1E3A5F`) sesuai branding Instagram `@santosafarma`.
5. **Kredensial Tidak Boleh Bocor:**
   - Jangan pernah menuliskan API key, Service Role Key, atau kredensial Supabase aktif secara langsung (*hardcode*) di dalam kode Dart/TypeScript maupun file `.md` yang di-commit ke Git.
