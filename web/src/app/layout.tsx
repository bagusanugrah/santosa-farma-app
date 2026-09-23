import './globals.css';
import type { Metadata } from 'next';
import { AuthProvider } from '@/context/AuthContext';
import { CartProvider } from '@/context/CartContext';
import Header from '@/components/Header';
import StoreClosedBanner from '@/components/StoreClosedBanner';
import CartDrawer from '@/components/CartDrawer';

export const metadata: Metadata = {
  title: 'Apotek Santosa Farma — Katalog Obat & Pesanan Online',
  description: 'Apotek Santosa Farma (Jalancagak, Subang) — Beli obat resmi, vitamin, dan suplemen online dengan mudah.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id">
      <body className="min-h-screen flex flex-col bg-slate-50 text-slate-900">
        <AuthProvider>
          <CartProvider>
            <StoreClosedBanner />
            <Header />
            <CartDrawer />
            <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
              {children}
            </main>
            <footer className="bg-white border-t border-slate-200 mt-auto py-8">
              <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center text-xs text-slate-500 space-y-2">
                <p className="font-bold text-slate-700">Apotek Santosa Farma</p>
                <p>Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat — Telp: (0260) 123456</p>
                <p className="text-slate-400">© {new Date().getFullYear()} Apotek Santosa Farma. Seluruh Hak Cipta Dilindungi.</p>
              </div>
            </footer>
          </CartProvider>
        </AuthProvider>
      </body>
    </html>
  );
}

