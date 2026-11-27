import './globals.css';
import type { Metadata, Viewport } from 'next';
import { AuthProvider } from '@/context/AuthContext';
import { CartProvider } from '@/context/CartContext';
import { StoreStatusProvider } from '@/context/StoreStatusContext';
import Header from '@/components/Header';
import StoreClosedBanner from '@/components/StoreClosedBanner';
import CartDrawer from '@/components/CartDrawer';
import MobileBottomNav from '@/components/MobileBottomNav';
import Footer from '@/components/Footer';

export const metadata: Metadata = {
  title: 'Apotek Santosa Farma — Katalog Obat & Pesanan Online',
  description: 'Apotek Santosa Farma — Beli obat resmi, vitamin, dan suplemen online dengan mudah.',
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id">
      <body className="min-h-screen flex flex-col bg-slate-50 text-slate-900 antialiased selection:bg-brand-100 selection:text-brand-900">
        <AuthProvider>
          <CartProvider>
            <StoreStatusProvider>
              <StoreClosedBanner />
              <Header />
              <CartDrawer />
              <main className="flex-1 max-w-7xl w-full mx-auto px-3.5 sm:px-6 lg:px-8 py-4 sm:py-8 pb-24 md:pb-8">
                {children}
              </main>
              <Footer />
              <MobileBottomNav />
            </StoreStatusProvider>
          </CartProvider>
        </AuthProvider>
      </body>
    </html>
  );
}

