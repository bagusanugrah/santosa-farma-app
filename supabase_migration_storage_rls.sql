-- ==============================================================================
-- MIGRATION: Kebijakan RLS Supabase Storage untuk Bucket 'products'
-- ==============================================================================
-- Jalankan seluruh query di bawah ini pada menu SQL Editor di Supabase Dashboard:
-- https://supabase.com/dashboard/project/nykoitxkyyhwvtrndyrb/sql
-- ==============================================================================

-- 1. Buat atau perbarui bucket 'products' agar berstatus publik
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

-- 2. Pastikan Row Level Security aktif pada tabel storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. Hapus kebijakan lama jika ada agar tidak terjadi duplikasi
DROP POLICY IF EXISTS "Public View Products Storage" ON storage.objects;
DROP POLICY IF EXISTS "Public Insert Products Storage" ON storage.objects;
DROP POLICY IF EXISTS "Public Update Products Storage" ON storage.objects;
DROP POLICY IF EXISTS "Public Delete Products Storage" ON storage.objects;

-- 4. Kebijakan SELECT (Publik / siapapun dapat melihat gambar obat)
CREATE POLICY "Public View Products Storage"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'products');

-- 5. Kebijakan INSERT (Izinkan aplikasi kasir mengunggah gambar obat)
CREATE POLICY "Public Insert Products Storage"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'products');

-- 6. Kebijakan UPDATE (Izinkan memperbarui gambar obat di bucket 'products')
CREATE POLICY "Public Update Products Storage"
ON storage.objects FOR UPDATE
TO public
USING (bucket_id = 'products');

-- 7. Kebijakan DELETE (Izinkan menghapus gambar obat dari bucket 'products')
CREATE POLICY "Public Delete Products Storage"
ON storage.objects FOR DELETE
TO public
USING (bucket_id = 'products');
