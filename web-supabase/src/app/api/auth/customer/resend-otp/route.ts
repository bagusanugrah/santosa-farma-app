import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { target, type } = body;

    if (!target || !type) {
      return NextResponse.json(
        { status: 'error', message: 'Target dan tipe verifikasi wajib diisi.' },
        { status: 400 }
      );
    }

    const field = type === 'phone' ? 'phone' : 'email';
    const { data: customer } = await supabaseAdmin
      .from('customers')
      .select('id')
      .eq(field, target)
      .maybeSingle();

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    await supabaseAdmin.from('otp_codes').insert({
      customer_id: customer?.id || null,
      type,
      target,
      code,
      expires_at: expiresAt,
    });

    console.log(`[Resent OTP for ${target}]: ${code}`);

    return NextResponse.json({
      status: 'success',
      message: `Kode OTP baru telah dikirimkan ke ${target}. (Kode: ${code})`,
      data: {
        debug_code: code,
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
