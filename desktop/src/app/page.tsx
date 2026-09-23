'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useStaffAuth } from '@/context/StaffAuthContext';

export default function RootPage() {
  const router = useRouter();
  const { user, loading } = useStaffAuth();

  useEffect(() => {
    if (loading) return;

    if (!user) {
      router.replace('/login');
    } else if (user.role === 'super_admin') {
      router.replace('/admin/dashboard');
    } else {
      router.replace('/pos');
    }
  }, [user, loading, router]);

  return (
    <div className="flex-1 flex items-center justify-center text-slate-400 font-medium text-sm">
      Memuat aplikasi Santosa Farma...
    </div>
  );
}

