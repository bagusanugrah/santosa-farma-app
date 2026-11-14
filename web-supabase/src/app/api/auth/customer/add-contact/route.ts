import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';

export async function POST(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json({ status: 'error', message: 'Unauthenticated.' }, { status: 401 });
    }

    const body = await req.json();
    const { type, target } = body;

    if (!type || !target || !['phone', 'email'].includes(type)) {
      return NextResponse.json(
        { status: 'error', message: 'Tipe dan kontak target wajib valid.' },
        { status: 422 }
      );
    }

    const trimmedTarget = target.trim();

    // Check if target is already used by another account
    const { data: existing } = await (supabaseAdmin.from('customers') as any)
      .select('id')
      .eq(type, trimmedTarget)
      .neq('id', customer.id)
      .maybeSingle();

    if (existing) {
      return NextResponse.json(
        {
          status: 'error',
          message: `${type === 'phone' ? 'Nomor WhatsApp' : 'Alamat email'} sudah digunakan oleh akun lain.`,
        },
        { status: 422 }
      );
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    await supabaseAdmin.from('otp_codes').insert({
      customer_id: customer.id,
      type,
      target: trimmedTarget,
      code,
      expires_at: expiresAt,
    });

    console.log(`[Add Contact OTP for ${trimmedTarget}]: ${code}`);

    return NextResponse.json({
      status: 'success',
      message: `Kode OTP telah dikirimkan ke ${trimmedTarget}. (Kode: ${code})`,
      data: {
        target: trimmedTarget,
        type,
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
