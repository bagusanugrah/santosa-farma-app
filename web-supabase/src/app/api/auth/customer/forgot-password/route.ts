import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { supabaseAdmin } from '@/lib/supabase';
import { sendPasswordResetNotification } from '@/lib/notifications';
import { getPhoneVariants } from '@/lib/server-auth';

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
        .limit(1)
        .maybeSingle();
      customer = data;
    } else {
      const { data } = await supabaseAdmin
        .from('customers')
        .select('*')
        .in('phone', getPhoneVariants(trimmed))
        .limit(1)
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

    const storedTarget = isEmail ? customer.email : customer.phone;
    const token = crypto.randomBytes(24).toString('hex');
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString(); // 30 minutes

    await supabaseAdmin.from('password_resets').insert({
      customer_id: customer.id,
      target: storedTarget,
      token,
      type: isEmail ? 'email' : 'phone',
      expires_at: expiresAt,
    });

    const relativeUrl = `/reset-password?token=${token}&target=${encodeURIComponent(storedTarget)}`;
    const proto = req.headers.get('x-forwarded-proto') || 'https';
    const host = req.headers.get('x-forwarded-host') || req.headers.get('host');
    const vercelOrigin = process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : '';
    const origin =
      req.headers.get('origin') ||
      process.env.WEB_URL ||
      (host ? `${proto}://${host}` : vercelOrigin || 'http://localhost:3000');
    const fullResetUrl = `${origin}${relativeUrl}`;

    // Send actual WhatsApp or Email reset link
    await sendPasswordResetNotification(
      customer.name,
      storedTarget,
      isEmail ? 'email' : 'phone',
      fullResetUrl
    );

    return NextResponse.json({
      status: 'success',
      message: `Link reset password telah dikirimkan ke ${isEmail ? 'email' : 'WhatsApp'} Anda. Silakan periksa pesan Anda.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
