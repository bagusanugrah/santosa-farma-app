# PROMPT PENGEMBANGAN SISTEM — APOTEK SANTOSA FARMA

Gunakan dokumen ini sebagai instruksi lengkap untuk AI (Claude Code / AI coding assistant lain) dalam membangun **sistem multi-aplikasi** untuk Apotek Santosa Farma (Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat). Sistem terdiri dari **1 backend API**, **1 aplikasi desktop**, **1 aplikasi web katalog**, dan **1 aplikasi Android kasir**, yang saling terintegrasi secara real-time.

---

## 1. KONTEKS PROYEK

Apotek Santosa Farma membutuhkan sistem terintegrasi untuk:
- Mengelola data produk (obat) dan transaksi penjualan di toko fisik (via aplikasi desktop kasir).
- Menjual produk secara online melalui katalog web, dengan pembayaran digital (Midtrans), lalu pengambilan barang dilakukan langsung di toko menggunakan kode QR.
- Memberi kasir fleksibilitas menerima pembayaran QRIS lewat HP (agar pelanggan tidak perlu scan dari layar komputer) dan memverifikasi pengambilan pesanan online lewat scan QR.
- Memberi super admin kontrol penuh atas data produk, laporan transaksi, dan analitik penjualan.

---

## 2. AKTOR / ROLE PENGGUNA

| Role | Akses |
|---|---|
| **Super Admin** | CRUD produk, lihat & export laporan transaksi (PDF) & produk (Excel), lihat dashboard analitik (grafik), kelola data di aplikasi desktop |
| **Admin Kasir** | Transaksi kasir (tunai/QRIS) di aplikasi desktop, cetak/simpan struk, konfirmasi pengambilan pesanan online via aplikasi Android |
| **Customer (Web)** | Registrasi/login (no HP atau email), lengkapi profil, cari & pesan produk, bayar via Midtrans, terima QR pengambilan pesanan |

---

## 3. ARSITEKTUR & TECH STACK

```
┌─────────────────────────┐        ┌──────────────────────────┐
│  Desktop App (Kasir/    │        │   Android App (Kasir)     │
│  Super Admin)           │        │   React Native + Tailwind │
│  Next.js + Tailwind +   │◄──────►│   (tampilkan QRIS,        │
│  Electron                │        │    scan QR pesanan)       │
└───────────┬──────────────┘        └────────────┬──────────────┘
            │  REST API (via ngrok saat app dibuka)             │
            ▼                                                    ▼
┌──────────────────────────────────────────────────────────────────┐
│    BACKEND: Laravel API + SQLite + Midtrans SDK                   │
│    Di-host lokal di komputer kasir, diekspos via ngrok            │
│    (menggunakan static domain gratis agar URL selalu tetap)       │
└───────────┬────────────────────────────────────────────────────┘
            │  REST API (via alamat ngrok static domain)
            ▼
┌──────────────────────────────┐
│  Web Client (Customer)       │
│  Next.js + Tailwind           │
│  Hosting: Vercel               │
└──────────────────────────────┘
```

**Stack wajib:**
- Backend: **Laravel** (API only) + **SQLite** + **Midtrans SDK** (Snap/Core API)
- Web Client: **Next.js + Tailwind CSS**, deploy di **Vercel**
- Desktop App: **Next.js + Tailwind CSS + Electron**
- Android App: **React Native + Tailwind (NativeWind)**
- Tunnel: **ngrok** (backend lokal → publik), dengan **1 static domain gratis** dari akun ngrok (fitur free-tier ngrok saat ini) sehingga URL backend **tidak berubah-ubah** tiap kali proses ngrok di-restart — tidak butuh domain sendiri seperti Cloudflare Tunnel.

---

## 4. MODUL BACKEND (Laravel API + SQLite + Midtrans)

### 4.1 Autentikasi & User Management
- Multi-guard auth: `super_admin`, `admin_kasir` (staff internal), `customer` (web).
- Staff internal (super admin & admin kasir) login pakai username/password, akun dibuat manual oleh super admin (tidak ada self-register untuk staff).
- Customer bisa register dengan **nomor HP** *atau* **email**:
  - Daftar dengan **no HP** → OTP dikirim via **WhatsApp** (gunakan API WhatsApp Gateway, mis. Fonnte/Wablas — buat konfigurasi environment-based).
  - Daftar dengan **email** → OTP dikirim via **email** (Laravel Mail).
  - Setelah akun aktif, di halaman profil, customer bisa melengkapi kontak yang belum diisi (misal sudah daftar pakai email, lalu tambah no HP, atau sebaliknya). **Setiap kali input kontak baru wajib verifikasi OTP ulang** sebelum kontak tersebut aktif dan bisa dipakai login.
  - Login bisa memakai no HP **atau** email (keduanya harus sudah terverifikasi).
- **Lupa password**: user input no HP atau email terdaftar → sistem kirim **link reset password** (via WA jika no HP, via email jika email) → link berlaku sementara (expiry token) → user set password baru.
- Gunakan **Laravel Sanctum** untuk token API (berbeda token/scope untuk staff dan customer).

### 4.2 Produk (CRUD — hanya Super Admin)
- Field: `nama`, `harga`, `stok`, `gambar` (nullable), `kategori` (opsional), `deskripsi` (opsional), `created_at/updated_at`.
- Jika `gambar` null → API tetap mengirim response konsisten, frontend yang menampilkan placeholder default.
- Endpoint list produk mendukung: `search` (nama produk), `sort=alphabet`, dan `pagination` dengan parameter `per_page` = 10 / 25 / 50 / 100.
- Simpan gambar di storage lokal Laravel (`storage/app/public`), expose via `php artisan storage:link`.

### 4.3 Transaksi
Dua sumber transaksi, disimpan dalam satu tabel `transactions` dengan field pembeda channel (`toko` / `online`):

**a. Transaksi Toko (via Desktop App / Kasir)**
- Kasir pilih produk → sistem hitung total → pilih metode bayar: `tunai` atau `qris`.
- Jika QRIS: backend generate QR code Midtrans (Core API charge QRIS), status transaksi `pending` → polling/webhook Midtrans untuk update status jadi `paid`.
- Setelah `paid`/tunai dikonfirmasi kasir → transaksi `selesai`, stok produk otomatis berkurang.
- QRIS bisa ditampilkan di **aplikasi Android kasir** (agar pelanggan scan dari HP kasir, bukan dari layar komputer) — backend expose endpoint untuk ambil QR string/gambar transaksi berjalan.

**b. Transaksi Online (via Web Katalog)**
- Customer checkout → pilih metode: **kartu kredit/debit**, **QRIS**, atau **Virtual Account bank** → integrasi **Midtrans Snap** (atau Core API).
- Setelah pembayaran **berhasil** (dikonfirmasi via webhook `notification` Midtrans), sistem:
  - Update status transaksi jadi `paid`.
  - Generate **QR Code unik** berisi order ID/token untuk pengambilan barang.
  - Kirim notifikasi ke customer (tampilkan di halaman "Pesanan Saya" web, opsional kirim WA/email juga).
- Status transaksi online: `pending` → `paid` → `diambil` (setelah kasir konfirmasi via scan QR) / `expired`/`gagal` jika pembayaran gagal.

### 4.4 Pengambilan Pesanan Online (via Android Kasir)
- Kasir scan QR code milik customer → backend validasi token QR → tampilkan detail pesanan (daftar obat, qty, total) di app Android.
- Kasir tekan tombol **"Konfirmasi Pesanan Diambil"** → backend update status transaksi jadi `diambil`, stok sudah dipotong sejak status `paid` (atau dipotong saat konfirmasi diambil — tentukan salah satu, disarankan potong stok saat status `paid` agar stok akurat untuk pesanan online lain).

### 4.5 Struk / Nota
- Setiap transaksi selesai (toko maupun online-diambil) bisa **dicetak** (print langsung dari desktop app ke printer thermal/biasa) atau **disimpan sebagai PDF**.
- File PDF struk disimpan di **local storage backend** (folder `storage/app/receipts`), backend menyediakan endpoint download PDF berdasarkan ID transaksi.

### 4.6 Export & Laporan (Super Admin)
- **Export PDF**: rekap penjualan/transaksi berdasarkan rentang tanggal (gunakan `barryvdh/laravel-dompdf` atau sejenis).
- **Export Excel**: daftar produk (gunakan `maatwebsite/excel`).
- **Endpoint analitik** untuk dashboard super admin, contoh data yang perlu disediakan:
  - Total penjualan per hari/minggu/bulan (untuk grafik batang).
  - Perbandingan channel transaksi: toko vs online (untuk grafik bundar/pie).
  - Produk terlaris (top selling products).
  - Perbandingan metode pembayaran (tunai vs QRIS vs kartu vs VA).

### 4.7 Status Toko (Buka/Tutup)
- Sediakan endpoint `GET /api/store/status` yang mengembalikan status toko `buka`/`tutup`.
- Status ini otomatis `buka` ketika desktop app aktif (backend & ngrok berjalan), dan otomatis `tutup` saat desktop app ditutup (lihat bagian 7 — Infrastruktur).

### 4.8 Struktur API secara umum
Rancang REST API dengan resource: `/api/auth/*`, `/api/products*`, `/api/transactions*`, `/api/store/status`, `/api/reports/*`, `/api/webhooks/midtrans`, dsb. Gunakan format response JSON konsisten (status, message, data, meta pagination).

---

## 5. MODUL DESKTOP APP (Next.js + Tailwind + Electron)

Aplikasi ini **satu codebase**, tapi tampilan/menu menyesuaikan role setelah login (super admin vs admin kasir).

### 5.1 Login
- Form login (username/password) → redirect sesuai role.

### 5.2 Untuk Admin Kasir
- Halaman **Kasir/POS**: pilih produk (search + grid dengan gambar, nama, harga, stok), keranjang transaksi, input metode bayar (tunai/QRIS).
- Jika QRIS: tampilkan QR di layar ATAU trigger tampil di app Android kasir (pilihan toggle).
- Setelah transaksi selesai: tombol **Cetak Struk** dan **Simpan PDF**.
- Halaman riwayat transaksi kasir (dengan pagination 10/25/50/100).

### 5.3 Untuk Super Admin
- Halaman **CRUD Produk**: tabel produk (gambar, nama, harga, stok) dengan pagination, form tambah/edit (upload gambar, placeholder jika kosong), hapus produk.
- Halaman **Transaksi**: lihat semua transaksi (toko + online) dengan filter & pagination.
- Halaman **Export**: tombol export PDF rekap transaksi & export Excel daftar produk.
- Halaman **Dashboard/Analitik**: grafik bundar (pie chart) & grafik batang (bar chart) — gunakan library seperti `recharts` atau `chart.js` — menampilkan data dari endpoint analitik (lihat 4.6).

### 5.4 Integrasi Ngrok (khusus Desktop App)
Lihat detail lengkap di Bagian 7.

---

## 6. MODUL WEB KATALOG (Next.js + Tailwind, hosting Vercel)

### 6.1 Halaman Katalog Produk
- Menampilkan semua produk **terurut abjad (A-Z)** secara default.
- Search bar untuk mencari obat berdasarkan nama.
- Tiap kartu produk menampilkan: **gambar** (placeholder jika null), **nama**, **harga**, **stok**.
- Pagination dengan pilihan 10/25/50/100 item per halaman.
- Jika status toko `tutup` (backend/ngrok mati) → tampilkan banner/halaman informasi "Apotek sedang tutup" dan **nonaktifkan fitur pencarian & transaksi** (tampilkan state khusus, bukan error biasa). Cek status via polling endpoint `GET /api/store/status` secara berkala.

### 6.2 Registrasi & Login
- Form daftar: pilih daftar via **No. HP** atau **Email**.
  - No HP → kirim OTP via WhatsApp, user input OTP untuk verifikasi.
  - Email → kirim OTP via email, user input OTP untuk verifikasi.
- Form login: input no HP **atau** email + password.
- Halaman **Profil**: user bisa melengkapi kontak yang belum ada (tambah email jika daftar dengan HP, atau sebaliknya). Setiap input kontak baru **wajib verifikasi OTP** sebelum tersimpan aktif.
- Halaman **Lupa Password**: input no HP/email → sistem kirim link reset (WA/email sesuai jenis kontak) → halaman reset password dari link tsb.

### 6.3 Pemesanan & Pembayaran
- Halaman detail produk → tambah ke keranjang → checkout.
- Checkout membutuhkan user login (redirect ke login jika belum).
- Pilihan metode bayar via **Midtrans**: kartu kredit/debit, QRIS, Virtual Account (BCA/BNI/BRI/Mandiri/Permata, dst — sesuai channel yang diaktifkan di Midtrans).
- Setelah pembayaran berhasil → tampilkan halaman sukses dengan **QR Code pengambilan pesanan**.
- Halaman **Pesanan Saya**: riwayat pesanan online beserta status (`pending`/`paid`/`diambil`/`expired`) dan tombol lihat/download QR pengambilan untuk pesanan yang belum diambil.

---

## 7. MODUL ANDROID APP KASIR (React Native + Tailwind/NativeWind)

- Login khusus admin kasir (role sama dengan desktop, akun sama).
- **Fitur 1 — Tampilkan QRIS**: menerima trigger dari desktop app (transaksi berjalan) dan menampilkan QR code pembayaran QRIS di layar HP agar pelanggan tinggal scan dari HP kasir.
- **Fitur 2 — Scan QR Pesanan Online**: buka kamera → scan QR milik customer → tampilkan detail pesanan (daftar obat, qty, total, nama pemesan) → tombol **"Konfirmasi Pesanan Diambil"** → update status transaksi ke backend.
- Realtime update status (gunakan polling interval atau, jika memungkinkan, Laravel Reverb/WebSocket untuk update instan antara desktop & Android).

---

## 8. INFRASTRUKTUR & DEPLOYMENT (Ngrok Auto Start/Stop)

Ini bagian kritikal yang menghubungkan semua modul. Gunakan **ngrok** untuk expose backend lokal ke internet.

### 8.1 Static Domain (agar URL tidak berubah-ubah)
- Buat akun ngrok (gratis cukup) dan aktifkan **1 static domain gratis** yang disediakan tiap akun ngrok (contoh hasilnya: `nama-acak.ngrok-free.app`, dan sejak fitur static domain tersedia, domain ini **bisa tetap dipakai berkali-kali** tanpa berubah — beda dari perilaku ngrok lama yang URL-nya selalu acak tiap sesi).
- Catat **auth token** dan **nama static domain** yang didapat, simpan sebagai environment variable (`NGROK_AUTHTOKEN`, `NGROK_DOMAIN`) yang dipakai Electron saat menjalankan proses ngrok.
- Dengan static domain ini, **tidak perlu punya domain sendiri** (beda dari Cloudflare Tunnel yang mewajibkan domain custom terhubung ke akun) — cukup pakai subdomain `*.ngrok-free.app` bawaan yang sudah tetap.
- ngrok tidak memiliki halaman interstitial seperti LocalTunnel, jadi **tidak perlu header bypass khusus** — request dari web client, desktop, Android, maupun webhook Midtrans bisa langsung mengakses API seperti biasa.

### 8.2 Alur Otomatisasi
1. **Saat Desktop App dibuka** (baik oleh kasir maupun super admin):
   - Electron main process otomatis menjalankan **Laravel backend** (`php artisan serve`) secara lokal.
   - Electron main process otomatis menjalankan **ngrok** (via binary `ngrok.exe`/`ngrok` atau library `@ngrok/ngrok` npm) dengan opsi **`--domain=<static-domain-kamu>`** agar URL publik selalu identik setiap kali dijalankan.
   - Setelah tunnel aktif, backend set status toko jadi `buka`.
2. **Saat Desktop App ditutup**:
   - Electron menjalankan proses cleanup: kirim request terakhir `POST /api/store/close` (update status toko jadi `tutup`), lalu stop proses backend Laravel dan stop proses ngrok.
3. **Web Client (Vercel)**:
   - Konfigurasi base URL backend di environment variable Vercel, langsung mengarah ke static domain ngrok (mis. `https://apotek-santosa-farma.ngrok-free.app`) — **tidak perlu update env tiap restart** karena domainnya tetap.
   - Polling `GET /api/store/status` secara berkala (misal tiap 15-30 detik) atau saat page load.
   - Jika gagal fetch (backend/tunnel mati) atau response status `tutup` → tampilkan state "Apotek Sedang Tutup", sembunyikan fitur pencarian & transaksi.

> **Catatan untuk AI developer**: Pastikan versi ngrok yang dipakai mendukung flag `--domain` (fitur static domain gratis). Simpan auth token ngrok sebagai environment variable, jangan hardcode di kode maupun commit ke repository. Uji ulang koneksi static domain secara berkala karena kebijakan free-tier ngrok bisa berubah sewaktu-waktu — siapkan juga rencana cadangan (misalnya upgrade ke paket berbayar ngrok) jika suatu saat static domain gratis dibatasi lebih lanjut.

---

## 9. FITUR UMUM LINTAS APLIKASI

- **Pagination**: semua list (produk, transaksi) mendukung pilihan tampil **10 / 25 / 50 / 100** data per halaman, dengan navigasi halaman (next/prev/nomor halaman).
- **Placeholder Gambar**: jika field gambar produk `null`, tampilkan gambar default/placeholder di seluruh tampilan (desktop, web, Android).
- **Tampilan Produk (kartu)**: konsisten di semua platform — gambar, nama, harga, stok.
- **Cetak/PDF Struk**: fitur cetak struk fisik (printer) dan simpan sebagai PDF (tersimpan di backend local storage) tersedia di transaksi toko maupun transaksi online yang sudah diambil.
- **Grafik Analitik**: pie chart (perbandingan channel/metode bayar) dan bar chart (tren penjualan per periode, produk terlaris) di dashboard super admin.

---

## 10. USULAN SKEMA DATABASE (SQLite)

- `users` (staff: super_admin, admin_kasir) — id, name, username, password, role
- `customers` — id, name, phone (nullable, unique), phone_verified_at, email (nullable, unique), email_verified_at, password
- `otp_codes` — id, customer_id, type(phone/email), code, target, expires_at, verified_at
- `password_resets` — id, customer_id, token, type(phone/email), expires_at
- `products` — id, name, price, stock, image (nullable), category, description
- `transactions` — id, invoice_no, channel(toko/online), customer_id(nullable), cashier_id(nullable), payment_method(tunai/qris/kartu/va), midtrans_order_id, status(pending/paid/diambil/selesai/expired/gagal), total, qr_token(nullable), created_at
- `transaction_items` — id, transaction_id, product_id, qty, price
- `receipts` — id, transaction_id, file_path

---

## 11. CATATAN TAMBAHAN

- Gunakan **environment variables** untuk semua kredensial sensitif: Midtrans server key/client key, WA Gateway API key, mail credentials, ngrok authtoken & nama static domain.
- Pastikan **webhook Midtrans** (`notification_url`) mengarah ke static domain ngrok backend dan divalidasi signature-nya sesuai dokumentasi resmi Midtrans.
- Jangan hardcode auth token ngrok di kode maupun commit ke repository — simpan sebagai environment variable/`.env`.
- Terapkan validasi input & rate limiting terutama pada endpoint OTP (cegah spam OTP) dan endpoint login.
- Pertimbangkan logging transaksi & audit trail untuk keperluan rekonsiliasi laporan super admin.

---

**Instruksi akhir untuk AI:** Bangun sistem ini bertahap — mulai dari backend Laravel (auth, produk, transaksi dasar) → integrasi Midtrans → desktop app (kasir & CRUD produk) → web katalog → integrasi ngrok (static domain) + status toko → Android app kasir → fitur export & analitik. Konfirmasi setiap modul selesai dan berfungsi sebelum lanjut ke modul berikutnya.
