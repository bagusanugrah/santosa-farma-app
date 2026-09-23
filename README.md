# Sistem Multi-Aplikasi Apotek Santosa Farma

Sistem terintegrasi untuk **Apotek Santosa Farma** (Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat) yang mencakup:
1. **Backend API**: Laravel 11 + SQLite Database (`database/database.sqlite`) + Sanctum Auth + Midtrans SDK (Snap & Core API QRIS) + DomPDF + PhpSpreadsheet.
2. **Desktop App (Kasir & Super Admin)**: Next.js + Tailwind CSS + Electron (Lifecycle backend & tunnel static domain ngrok).
3. **Web Client (Katalog Pelanggan)**: Next.js + Tailwind CSS (Katalog A-Z, customer OTP WA/Email, Midtrans Snap checkout, QR Pengambilan).
4. **Android App (Kasir)**: React Native / Expo + NativeWind (Tampilkan QRIS ke pembeli & scan QR pengambilan pesanan online).

---

## 1. Struktur Direktori Proyek

```
apotek-santosa-farma/
├── backend/                  # Laravel 11 REST API (Database SQLite)
│   ├── app/Http/Controllers/Api/
│   ├── app/Models/
│   ├── app/Services/
│   ├── database/database.sqlite
│   ├── database/migrations/
│   ├── database/seeders/
│   └── routes/api.php
├── desktop/                  # Next.js + Tailwind + Electron (POS Kasir & Admin)
│   ├── electron/             # main.js & preload.js (Auto-start backend & ngrok)
│   └── src/app/              # POS, POS History, Dashboard, Products, Transactions, Export
├── web/                      # Next.js + Tailwind (Katalog Web Pelanggan)
│   └── src/app/              # Katalog A-Z, Auth OTP, Profil, Checkout Midtrans, Pesanan Saya
└── android/                  # React Native Expo (Android App Kasir)
    └── src/screens/          # Login, ShowQris, ScanPickup
```

---

## 2. Kredensial Akun Default

| Tipe Akun | Role | Identitas / Username | Password |
|---|---|---|---|
| **Super Admin** | `super_admin` | `admin` | `password123` |
| **Admin Kasir** | `admin_kasir` | `kasir` | `password123` |
| **Customer Web** | `customer` | `081234567890` atau `siti@example.com` | `password123` |

---

## 3. Menjalankan Aplikasi

### A. Backend API (Laravel 11 — SQLite)
```bash
cd backend
php artisan serve --port=8000
```
> Menjalankan test otomatis: `php artisan test`

### B. Web Client Katalog (Customer)
```bash
cd web
npm run dev
# Buka di browser: http://localhost:3000
```

### C. Desktop App (Kasir & Super Admin)
```bash
cd desktop
npm run dev
# Menjalankan Next.js di port 3001 dan membuka window Electron secara otomatis
```

### D. Android App Kasir (React Native Expo)
```bash
cd android
npx expo start
# Buka di Expo Go di Android fisik atau Android Emulator
```

---

## 4. Konfigurasi Environment & Ngrok Static Domain

- **Backend (`backend/.env`)**:
  - `DB_CONNECTION=sqlite`
  - `MIDTRANS_SERVER_KEY`: Server key sandbox / production Midtrans
  - `MIDTRANS_CLIENT_KEY`: Client key Midtrans
  - `WA_GATEWAY_TOKEN`: Token API WhatsApp Gateway (Fonnte / Wablas)
  - `NGROK_AUTHTOKEN` & `NGROK_DOMAIN`: Token ngrok dan nama static domain gratis (mis. `apotek-santosa-farma.ngrok-free.app`)
- **Desktop (`desktop/.env.local`)**:
  - `NEXT_PUBLIC_API_URL=http://localhost:8000/api`
- **Web (`web/.env.local`)**:
  - `NEXT_PUBLIC_API_URL=http://localhost:8000/api` (atau URL static domain ngrok saat deploy di Vercel)
