import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader, verifyPassword, hashPassword } from '@/lib/server-auth';

export async function POST(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json({ status: 'error', message: 'Unauthenticated.' }, { status: 401 });
    }

    const body = await req.json();
    const { current_password, new_password, new_password_confirmation } = body;

    if (!current_password || !new_password) {
      return NextResponse.json(
        { status: 'error', message: 'Semua kolom password wajib diisi.' },
        { status: 422 }
      );
    }

    if (new_password.length < 8) {
      return NextResponse.json(
        { status: 'error', message: 'Password baru minimal 8 karakter.' },
        { status: 422 }
      );
    }

    if (new_password !== new_password_confirmation) {
      return NextResponse.json(
        { status: 'error', message: 'Konfirmasi password baru tidak cocok.' },
        { status: 422 }
      );
    }

    const isMatch = await verifyPassword(current_password, customer.password);
    if (!isMatch) {
      return NextResponse.json(
        { status: 'error', message: 'Password saat ini yang Anda masukkan salah.' },
        { status: 422 }
      );
    }

    const newHashed = await hashPassword(new_password);
    const { error } = await supabaseAdmin
      .from('customers')
      .update({ password: newHashed, updated_at: new Date().toISOString() })
      .eq('id', customer.id);

    if (error) {
      return NextResponse.json(
        { status: 'error', message: error.message || 'Gagal mengubah password.' },
        { status: 500 }
      );
    }

    return NextResponse.json({
      status: 'success',
      message: 'Password berhasil diperbarui.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
