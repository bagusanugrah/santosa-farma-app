# Apotek Santosa Farma — Sistem Kasir POS & Pemesanan Web

Sistem informasi apotek modern dan terintegrasi untuk **Apotek Santosa Farma** (Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat). Sistem ini menghubungkan aplikasi kasir toko (Android POS) dengan portal pemesanan obat online bagi pelanggan (Web Next.js) menggunakan **Supabase PostgreSQL** sebagai pusat data realtime.

Branding, palet warna (*Medical Cyan / Teal* `#0891B2` / `#4AB8C4` & *Deep Navy* `#1E3A5F`), serta logo resmi diselaraskan langsung dengan identitas visual resmi Instagram [**@santosafarma**](https://instagram.com/santosafarma).

---

## 🏛️ Arsitektur Proyek

```
apotek-santosa-farma/
├── android/                                    # Aplikasi Android POS Kasir (Flutter)
│   ├── lib/
│   │   ├── config/theme.dart                   # Tema resmi Cyan/Teal Instagram @santosafarma
│   │   ├── config/supabase_config.dart         # Konfigurasi Cloud Supabase
│   │   ├── models/                             # Product, Transaction, StoreSetting, User
│   │   ├── providers/                          # PosProvider, WebOrdersProvider, StoreProvider
│   │   ├── screens/                            # POS, Products, Web Orders, QR Scanner, Reports, Settings
│   │   └── widgets/                            # CartView, PaymentDialog, ProcessWebOrderDialog, ReceiptDialog
│   └── pubspec.yaml
│
├── web-supabase/                               # Portal Web Pelanggan (Next.js 14 App Router)
│   ├── src/
│   │   ├── app/                                # Katalog (/), Checkout, Orders, Profile, Auth OTP
│   │   ├── components/                         # Header, ProductCard, CartDrawer, QrPickupModal
│   │   ├── context/                            # AuthContext, CartContext, StoreStatusContext
│   │   └── lib/                                # Supabase client & server-side admin SDK
│   ├── tailwind.config.js                      # Tailwind theme resmi Santosa Farma
│   └── package.json
│
├── supabase_schema.sql                         # Skema lengkap PostgreSQL & RLS Supabase
└── supabase_migration_integration_settings.sql # Migrasi store_settings (Midtrans & Fonnte)
```

---

## 🔐 Kredensial Akun Default

> [!IMPORTANT]
> Demi keamanan kasir fisik, kredensial login **tidak ditampilkan di layar aplikasi**. Gunakan kredensial default berikut untuk login awal:

| Tipe Akun | Role | Username / Kontak | Password Default | Keterangan |
|---|---|---|---|---|
| **Super Admin** | `super_admin` | `admin` | `password123` | Akses penuh: Integrasi Gateway (Midtrans/Fonnte), Manajemen Produk, Laporan Transaksi, & Backup Data |
| **Kasir Toko** | `admin_kasir` | `kasir` | `password123` | Akses kasir: Transaksi POS (Tunai/QRIS), Proses & Edit Pesanan Web, Scan QR Pengambilan Obat |
| **Customer Web** | `customer` | `081234567890` / `siti@example.com` | `password123` | Pelanggan web dapat mendaftar/login mandiri dengan verifikasi OTP WhatsApp / Email |

---

## ✨ Fitur-Fitur Unggulan

### 1. Aplikasi Kasir Android POS (`android/`)
- **Desain Responsif**: Otomatis menyesuaikan tampilan untuk layar smartphone vertikal maupun tablet horizontal (Side Navigation Rail & Grid POS).
- **Proses Transaksi Kasir**:
  - Tombol uang pas cepat (*quick cash*): Rp 10.000, Rp 20.000, Rp 50.000, Rp 100.000, dll.
  - Perhitungan kembalian otomatis realtime.
  - Pembayaran QRIS (hanya aktif jika kredensial Midtrans telah diisi secara valid).
- **Proses & Edit Pesanan Web di Kasir (`ProcessWebOrderDialog`)**:
  - Pelanggan yang memesan dari web dengan opsi **"Bayar di Apotek"** dapat diproses dan diedit oleh kasir.
  - Kasir dapat menyesuaikan jumlah obat (*stepper qty*), menghapus obat jika stok fisik habis/batal, atau menambahkan obat baru langsung dari katalog apotek.
  - Kasir menerima pembayaran (Tunai/QRIS) di tempat, stok obat faktual otomatis berkurang, dan struk resmi langsung dicetak.
- **Scan QR Pengambilan Obat**: Scanner kamera terintegrasi (`mobile_scanner`) dengan senter (*torch*) dan input manual nomor invoice.
- **Notifikasi Pesanan Masuk Realtime**: Supabase Realtime membunyikan audio lonceng (*chime*) seketika saat ada pesanan online masuk dari website.
- **Pencetakan Struk Digital & Fisik**: Mendukung cetak struk thermal via Bluetooth printer atau pratinjau struk digital.
- **Pengaturan Toko & Keamanan**:
  - Sakelar Buka/Tutup Apotek.
  - Sakelar Transaksi Web Pelanggan (dapat dinyalakan/dimatikan bebas oleh kasir).
  - Cadangkan database transaksi dan produk ke file ZIP terenkripsi atau simpan ke Google Drive.

### 2. Portal Web Pelanggan (`web-supabase/`)
- **Katalog Obat Digital**: Filter kategori (Antibiotik, Analgesik, Flu & Batuk, dll.), pencarian instan, dan indikator status buka/tutup apotek secara realtime.
- **Opsi Pembayaran Fleksibel**:
  - **Bayar di Apotek (Kasir)**: Pesan obat lewat web, bayar langsung di kasir (Tunai / QRIS). Tetap berfungsi meskipun gateway online Midtrans belum dikonfigurasi.
  - **Bayar Online Sekarang (Midtrans Snap)**: Bayar instan via QRIS, GoPay, ShopeePay, atau Virtual Account Bank (otomatis aktif jika admin telah memasukkan kredensial Midtrans).
- **QR Code Pesanan**: Pelanggan otomatis mendapatkan QR Code bukti pesanan/pengambilan obat untuk ditunjukkan ke kasir saat tiba di apotek.
- **Autentikasi Aman**: Registrasi & login pelanggan dengan verifikasi OTP via WhatsApp Gateway (Fonnte) atau Email SMTP.

---

## 🚀 Panduan Menjalankan & Membangun

### A. Web Pelanggan (`web-supabase`)

1. **Instalasi Dependensi**:
   ```bash
   cd web-supabase
   npm install
   ```

2. **File Environment (`.env.local`)**:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://nykoitxkyyhwvtrndyrb.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   NEXT_PUBLIC_MIDTRANS_CLIENT_KEY=Mid-client-xxxxxxxxxxxxxxxx
   NEXT_PUBLIC_MIDTRANS_IS_PRODUCTION=false
   MIDTRANS_SERVER_KEY=Mid-server-xxxxxxxxxxxxxxxx
   ```

3. **Jalankan Development Server**:
   ```bash
   npm run dev
   # Akses di browser: http://localhost:3000
   ```

4. **Build untuk Produksi (Vercel)**:
   ```bash
   npm run build
   ```

---

### B. Aplikasi Android POS (`android`)

1. **Persiapan Flutter**:
   Pastikan Flutter SDK (versi >= 3.24) dan Android SDK telah terpasang.
   ```bash
   cd android
   flutter pub get
   ```

2. **Jalankan Aplikasi (Mode Debug)**:
   Sambungkan HP Android atau jalankan Android Emulator:
   ```bash
   flutter run
   ```

3. **Build APK Rilis (Production)**:
   ```bash
   flutter build apk --release
   ```
   File APK hasil kompilasi akan berada di:
   `android/build/app/outputs/flutter-apk/app-release.apk`

---

## 🗄️ Setup Database Supabase

1. Buka project dashboard di [Supabase](https://supabase.com).
2. Jalankan perintah SQL dari file `supabase_schema.sql` pada menu **SQL Editor**.
3. Jalankan migrasi tambahan dari file `supabase_migration_integration_settings.sql`.
4. Pastikan fitur **Supabase Realtime** aktif untuk tabel:
   - `public.transactions`
   - `public.store_settings`
   - `public.products`
5. Atur bucket storage publik dengan nama `products` untuk upload gambar obat.

---

## 📄 Lisensi & Hak Cipta
Hak Cipta © 2026 **Apotek Santosa Farma**. Semua hak dilindungi undang-undang.
Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat.
Instagram: [@santosafarma](https://instagram.com/santosafarma)
