import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { sendOtpNotification } from '@/lib/notifications';
import { getCustomerFromAuthHeader, getPhoneVariants } from '@/lib/server-auth';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { target, type } = body;

    if (!target || !type || !['phone', 'email'].includes(type)) {
      return NextResponse.json(
        { status: 'error', message: 'Target dan tipe verifikasi wajib diisi.' },
        { status: 400 }
      );
    }

    const normalizedTarget =
      type === 'email' ? String(target).trim().toLowerCase() : String(target).trim();

    let customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      if (type === 'phone') {
        const { data } = await supabaseAdmin
          .from('customers')
          .select('id')
          .in('phone', getPhoneVariants(normalizedTarget))
          .limit(1)
          .maybeSingle();
        customer = data;
      } else {
        const { data } = await supabaseAdmin
          .from('customers')
          .select('id')
          .ilike('email', normalizedTarget)
          .limit(1)
          .maybeSingle();
        customer = data;
      }
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { data: insertedOtp, error: otpErr } = await supabaseAdmin
      .from('otp_codes')
      .insert({
        customer_id: customer?.id || null,
        type,
        target: normalizedTarget,
        code,
        expires_at: expiresAt,
      })
      .select('id')
      .single();

    if (otpErr || !insertedOtp) {
      return NextResponse.json(
        { status: 'error', message: otpErr?.message || 'Gagal menyiapkan kode OTP.' },
        { status: 500 }
      );
    }

    // Send actual WhatsApp or Email message; delete OTP record if delivery fails
    const sent = await sendOtpNotification(normalizedTarget, type, code);
    if (!sent) {
      await supabaseAdmin.from('otp_codes').delete().eq('id', insertedOtp.id);
      return NextResponse.json(
        {
          status: 'error',
          message:
            type === 'phone'
              ? 'Gagal mengirim ulang OTP ke WhatsApp. Pastikan gateway WhatsApp aktif.'
              : 'Gagal mengirim ulang OTP ke Email. Pastikan konfigurasi SMTP email aktif.',
        },
        { status: 502 }
      );
    }

    return NextResponse.json({
      status: 'success',
      message: `Kode OTP baru telah dikirimkan ke ${type === 'phone' ? 'WhatsApp' : 'email'} ${normalizedTarget}.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
