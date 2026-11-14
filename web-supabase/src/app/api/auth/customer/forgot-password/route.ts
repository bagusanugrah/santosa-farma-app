import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { supabaseAdmin } from '@/lib/supabase';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { target } = body;

    if (!target || !target.trim()) {
      return NextResponse.json(
        { status: 'error', message: 'Nomor WhatsApp atau Email wajib diisi.' },
        { status: 422 }
      );
    }

    const trimmed = target.trim();
    const isEmail = trimmed.includes('@');

    let customer = null;
    if (isEmail) {
      const { data } = await supabaseAdmin
        .from('customers')
        .select('*')
        .ilike('email', trimmed)
        .maybeSingle();
      customer = data;
    } else {
      const { data } = await supabaseAdmin
        .from('customers')
        .select('*')
        .eq('phone', trimmed)
        .maybeSingle();
      customer = data;
    }

    if (!customer) {
      // Don't leak if account exists or not for security
      return NextResponse.json({
        status: 'success',
        message: 'Jika akun terdaftar, link reset password telah dikirimkan ke kontak Anda.',
      });
    }

    const token = crypto.randomBytes(24).toString('hex');
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString(); // 30 minutes

    await supabaseAdmin.from('password_resets').insert({
      customer_id: customer.id,
      target: trimmed,
      token,
      type: isEmail ? 'email' : 'phone',
      expires_at: expiresAt,
    });

    console.log(`[Password Reset Token for ${trimmed}]: ${token}`);

    return NextResponse.json({
      status: 'success',
      message: `Link reset password telah dibuat. Silakan periksa pesan Anda.`,
      reset_url: `/reset-password?token=${token}&target=${encodeURIComponent(trimmed)}`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
