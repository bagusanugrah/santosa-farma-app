-- ============================================================
-- APOTEK SANTOSA FARMA — SUPABASE POSTGRESQL SCHEMA & SEEDER
-- ============================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 2. TABLES DEFINITION
-- ============================================================

-- USERS (Staff / Kasir & Super Admin)
CREATE TABLE IF NOT EXISTS public.users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'admin_kasir', -- 'super_admin' or 'admin_kasir'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- CUSTOMERS (Pelanggan Web)
CREATE TABLE IF NOT EXISTS public.customers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) UNIQUE,
    phone_verified_at TIMESTAMPTZ,
    email VARCHAR(255) UNIQUE,
    email_verified_at TIMESTAMPTZ,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- OTP CODES (Verifikasi Pelanggan Web)
CREATE TABLE IF NOT EXISTS public.otp_codes (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT REFERENCES public.customers(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL, -- 'phone' or 'email'
    target VARCHAR(255) NOT NULL,
    code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- PASSWORD RESETS
CREATE TABLE IF NOT EXISTS public.password_resets (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT REFERENCES public.customers(id) ON DELETE CASCADE,
    target VARCHAR(255) NOT NULL,
    token VARCHAR(64) NOT NULL,
    type VARCHAR(20) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- PRODUCTS (Katalog Obat Apotek)
CREATE TABLE IF NOT EXISTS public.products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    stock INT NOT NULL DEFAULT 0,
    description TEXT,
    image TEXT, -- Path or Full URL to Supabase Storage
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- STORE SETTINGS (Pengaturan Buka/Tutup & Pesanan Online)
CREATE TABLE IF NOT EXISTS public.store_settings (
    id INT PRIMARY KEY DEFAULT 1,
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    online_orders_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    last_opened_at TIMESTAMPTZ,
    last_closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT single_store_setting CHECK (id = 1)
);

-- TRANSACTIONS (POS Kasir & Online Web)
CREATE TABLE IF NOT EXISTS public.transactions (
    id BIGSERIAL PRIMARY KEY,
    invoice_no VARCHAR(100) NOT NULL UNIQUE,
    channel VARCHAR(20) NOT NULL DEFAULT 'toko', -- 'toko' or 'online'
    customer_id BIGINT REFERENCES public.customers(id) ON DELETE SET NULL,
    cashier_id BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'tunai', -- 'tunai', 'qris', 'kartu', 'va'
    midtrans_order_id VARCHAR(100),
    midtrans_snap_token TEXT,
    midtrans_qris_url TEXT,
    midtrans_va_number VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'paid', 'diambil', 'selesai', 'expired', 'gagal'
    total NUMERIC(12, 2) NOT NULL DEFAULT 0,
    amount_paid NUMERIC(12, 2),
    change_amount NUMERIC(12, 2),
    qr_token VARCHAR(64) UNIQUE,
    paid_at TIMESTAMPTZ,
    picked_up_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TRANSACTION ITEMS (Rincian Obat Terjual)
CREATE TABLE IF NOT EXISTS public.transaction_items (
    id BIGSERIAL PRIMARY KEY,
    transaction_id BIGINT NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES public.products(id) ON DELETE SET NULL,
    product_name VARCHAR(255) NOT NULL,
    qty INT NOT NULL DEFAULT 1,
    price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RECEIPTS (Struk Digital)
CREATE TABLE IF NOT EXISTS public.receipts (
    id BIGSERIAL PRIMARY KEY,
    transaction_id BIGINT NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. ENABLE SUPABASE REALTIME (Untuk Notifikasi Instan ke HP Kasir)
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.store_settings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;

-- ============================================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_resets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

-- Allow public read access to catalog & store settings
CREATE POLICY "Public can view products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Public can view store settings" ON public.store_settings FOR SELECT USING (true);

-- Allow full access for anon/service for now (can be tightened via API tokens)
CREATE POLICY "Allow anon all on products" ON public.products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all on transactions" ON public.transactions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all on transaction_items" ON public.transaction_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all on store_settings" ON public.store_settings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all on users" ON public.users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all on customers" ON public.customers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all on otp_codes" ON public.otp_codes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all on password_resets" ON public.password_resets FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all on receipts" ON public.receipts FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 5. INITIAL SEED DATA
-- ============================================================

-- Staff Users (Password: password123 with bcrypt hash)
INSERT INTO public.users (name, username, password, role)
VALUES 
    ('Super Admin', 'admin', crypt('password123', gen_salt('bf')), 'super_admin'),
    ('Kasir', 'kasir', crypt('password123', gen_salt('bf')), 'admin_kasir')
ON CONFLICT (username) DO NOTHING;

-- Store Settings (Default Buka, Pesanan Online Nonaktif awal)
INSERT INTO public.store_settings (id, is_open, online_orders_enabled, last_opened_at)
VALUES (1, TRUE, FALSE, NOW())
ON CONFLICT (id) DO UPDATE 
SET is_open = EXCLUDED.is_open,
    online_orders_enabled = EXCLUDED.online_orders_enabled;

-- Initial Medicine Catalog
INSERT INTO public.products (name, category, price, stock, description)
VALUES 
    ('Amoxicillin 500mg Strip (10 Kaplet)', 'Antibiotik', 12000, 50, 'Antibiotik untuk mengobati infeksi bakteri.'),
    ('Antasida Doen Tablet Kunyah', 'Pencernaan', 6000, 80, 'Meredakan sakit maag, asam lambung berlebih, dan nyeri ulu hati.'),
    ('Betadine Antiseptic Solution 30ml', 'P3K', 32000, 35, 'Cairan antiseptik pembersih luka dan pencegah infeksi.'),
    ('Bodrex Sakit Kepala Strip (20 Tablet)', 'Analgesik', 11000, 100, 'Meredakan sakit kepala, sakit gigi, dan penurun demam.'),
    ('CDR Vitamin C Effervescent Rasa Jeruk (10 Tablet)', 'Vitamin', 48000, 40, 'Suplemen kalsium dan vitamin C, D, B6.'),
    ('Combantrin Jeruk 125mg Suspensi 10ml', 'Obat Cacing', 21000, 25, 'Obat cacing untuk melumpuhkan dan membasmi cacing.'),
    ('Decolgen Strip (4 Tablet)', 'Flu & Batuk', 4500, 75, 'Meringankan gejala flu, bersin-bersin, dan hidung tersumbat.'),
    ('Diapet Kapsul (Box 25 Strip)', 'Pencernaan', 7000, 90, 'Membantu memadatkan feses dan meredakan diare.'),
    ('Enervon-C Multivitamin Strip (4 Tablet)', 'Vitamin', 8500, 120, 'Kombinasi vitamin C dan B kompleks pemelihara daya tahan tubuh.'),
    ('Hansaplast Plester Luka Standar (10 Lembar)', 'P3K', 7500, 150, 'Plester elastis pelindung luka dari kotoran dan kuman.'),
    ('Imboost Force Tablet Strip (10 Kaplet)', 'Daya Tahan Tubuh', 85000, 30, 'Suplemen imunomodulator dengan Echinacea purpurea.'),
    ('Minyak Kayu Putih Cap Lang 60ml', 'Minyak Angin', 24000, 60, 'Meredakan perut kembung, masuk angin, dan menghangatkan tubuh.')
ON CONFLICT DO NOTHING;
