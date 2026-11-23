-- ==============================================================================
-- MIGRATION: Kebijakan RLS Supabase Storage untuk Bucket 'products'
-- ==============================================================================
-- Jalankan query di bawah ini di menu SQL Editor Supabase:
-- (CATATAN: JANGAN masukkan 'ALTER TABLE storage.objects' karena RLS sudah aktif
-- bawaan dan tabel storage dimiliki oleh role internal Supabase).
-- ==============================================================================

-- 1. Pastikan bucket 'products' berstatus publik
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'products',
    'products',
    true,
    5242880, -- Maksimal 5MB per file foto
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'image/gif']
)
ON CONFLICT (id) DO UPDATE 
SET public = true,
    file_size_limit = 5242880;

-- 2. Hapus kebijakan lama jika ada agar tidak terjadi duplikasi error
DROP POLICY IF EXISTS "Public View Products Storage" ON storage.objects;
DROP POLICY IF EXISTS "Public Insert Products Storage" ON storage.objects;
DROP POLICY IF EXISTS "Public Update Products Storage" ON storage.objects;
DROP POLICY IF EXISTS "Public Delete Products Storage" ON storage.objects;

-- 3. Kebijakan SELECT (Publik / siapapun dapat melihat gambar obat)
CREATE POLICY "Public View Products Storage"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'products');

-- 4. Kebijakan INSERT (Izinkan aplikasi kasir mengunggah gambar obat)
CREATE POLICY "Public Insert Products Storage"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'products');

-- 5. Kebijakan UPDATE (Izinkan memperbarui gambar obat di bucket 'products')
CREATE POLICY "Public Update Products Storage"
ON storage.objects FOR UPDATE
TO public
USING (bucket_id = 'products');

-- 6. Kebijakan DELETE (Izinkan menghapus gambar obat dari bucket 'products')
CREATE POLICY "Public Delete Products Storage"
ON storage.objects FOR DELETE
TO public
USING (bucket_id = 'products');
