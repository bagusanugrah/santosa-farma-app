import './globals.css';
import type { Metadata } from 'next';
import { StaffAuthProvider } from '@/context/StaffAuthContext';
import Sidebar from '@/components/Sidebar';

export const metadata: Metadata = {
  title: 'Apotek Santosa Farma — POS Kasir & Super Admin',
  description: 'Sistem Kasir dan Manajemen Apotek Santosa Farma',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id">
      <body className="min-h-screen bg-slate-100 flex text-slate-900 overflow-hidden">
        <StaffAuthProvider>
          <Sidebar />
          <main className="flex-1 h-screen overflow-y-auto bg-slate-50 flex flex-col">
            {children}
          </main>
        </StaffAuthProvider>
      </body>
    </html>
  );
}

