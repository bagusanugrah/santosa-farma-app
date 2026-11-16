-- ==============================================================================
-- MIGRATION: Integrasi Gateway (WhatsApp, Email & Midtrans) ke store_settings
-- Jalankan query ini di Supabase SQL Editor jika kolom belum ada di database.
-- ==============================================================================

ALTER TABLE public.store_settings 
ADD COLUMN IF NOT EXISTS fonnte_token TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS fonnte_url TEXT DEFAULT 'https://api.fonnte.com/send',
ADD COLUMN IF NOT EXISTS mail_host TEXT DEFAULT 'smtp.gmail.com',
ADD COLUMN IF NOT EXISTS mail_port INT DEFAULT 587,
ADD COLUMN IF NOT EXISTS mail_username TEXT DEFAULT 'kucitcloud@gmail.com',
ADD COLUMN IF NOT EXISTS mail_password TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS mail_from_name TEXT DEFAULT 'Apotek Santosa Farma',
ADD COLUMN IF NOT EXISTS midtrans_client_key TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS midtrans_server_key TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS midtrans_is_production BOOLEAN DEFAULT FALSE;
