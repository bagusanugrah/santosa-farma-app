import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { hashPassword } from '@/lib/server-auth';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { token, target, password } = body;

    if (!token || !target || !password) {
      return NextResponse.json(
        { status: 'error', message: 'Token, target, dan password baru wajib diisi.' },
        { status: 422 }
      );
    }

    if (password.length < 8) {
      return NextResponse.json(
        { status: 'error', message: 'Password baru minimal 8 karakter.' },
        { status: 422 }
      );
    }

    // Validate reset token
    const { data: resetRecord } = await supabaseAdmin
      .from('password_resets')
      .select('*')
      .eq('token', token)
      .eq('target', target)
      .is('used_at', null)
      .gte('expires_at', new Date().toISOString())
      .order('id', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!resetRecord) {
      return NextResponse.json(
        { status: 'error', message: 'Link reset password tidak valid atau sudah kadaluarsa.' },
        { status: 400 }
      );
    }

    const hashedPassword = await hashPassword(password);

    // Update customer password
    const { error: updateCustomerErr } = await supabaseAdmin
      .from('customers')
      .update({ password: hashedPassword, updated_at: new Date().toISOString() })
      .eq('id', resetRecord.customer_id);

    if (updateCustomerErr) {
      return NextResponse.json(
        { status: 'error', message: 'Gagal memperbarui password akun.' },
        { status: 500 }
      );
    }

    // Mark reset token used
    await supabaseAdmin
      .from('password_resets')
      .update({ used_at: new Date().toISOString() })
      .eq('id', resetRecord.id);

    return NextResponse.json({
      status: 'success',
      message: 'Password berhasil diubah. Silakan login kembali dengan password baru Anda.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
