import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { verifyPassword, signCustomerJwt, getPhoneVariants } from '@/lib/server-auth';
import { sendOtpNotification } from '@/lib/notifications';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { login, password } = body;

    // Check store setting: online orders enabled
    const { data: storeSetting } = await supabaseAdmin
      .from('store_settings')
      .select('online_orders_enabled')
      .eq('id', 1)
      .maybeSingle();

    if (!storeSetting?.online_orders_enabled) {
      return NextResponse.json(
        {
          status: 'error',
          message:
            'Layanan login & pembelian online sedang dinonaktifkan oleh kasir. Silakan lakukan pembelian langsung di kasir Apotek Santosa Farma.',
        },
        { status: 403 }
      );
    }

    if (!login || !password) {
      return NextResponse.json(
        { status: 'error', message: 'No. HP / Email dan password wajib diisi.' },
        { status: 422 }
      );
    }

    const trimmedLogin = login.trim();
    const isEmail = trimmedLogin.includes('@');

    let customer = null;
    if (isEmail) {
      const { data } = await supabaseAdmin
        .from('customers')
        .select('*')
        .ilike('email', trimmedLogin)
        .limit(1)
        .maybeSingle();
      customer = data;
    } else {
      const { data } = await supabaseAdmin
        .from('customers')
        .select('*')
        .in('phone', getPhoneVariants(trimmedLogin))
        .limit(1)
        .maybeSingle();
      customer = data;
    }

    if (!customer) {
      return NextResponse.json(
        { status: 'error', message: 'No. HP / Email atau password salah.' },
        { status: 401 }
      );
    }

    const passwordMatch = await verifyPassword(password, customer.password);
    if (!passwordMatch) {
      return NextResponse.json(
        { status: 'error', message: 'No. HP / Email atau password salah.' },
        { status: 401 }
      );
    }

    // Check verification status — send fresh OTP automatically if unverified
    if (isEmail && !customer.email_verified_at) {
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
      await supabaseAdmin.from('otp_codes').insert({
        customer_id: customer.id,
        type: 'email',
        target: customer.email,
        code,
        expires_at: expiresAt,
      });
      await sendOtpNotification(customer.email, 'email', code);

      return NextResponse.json(
        {
          status: 'error',
          message: 'Email belum diverifikasi. Kode OTP baru telah dikirim ke email Anda.',
          require_verification: true,
          target: customer.email,
          type: 'email',
        },
        { status: 403 }
      );
    }

    if (!isEmail && !customer.phone_verified_at) {
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
      await supabaseAdmin.from('otp_codes').insert({
        customer_id: customer.id,
        type: 'phone',
        target: customer.phone,
        code,
        expires_at: expiresAt,
      });
      await sendOtpNotification(customer.phone, 'phone', code);

      return NextResponse.json(
        {
          status: 'error',
          message: 'Nomor WhatsApp belum diverifikasi. Kode OTP baru telah dikirim ke WhatsApp Anda.',
          require_verification: true,
          target: customer.phone,
          type: 'phone',
        },
        { status: 403 }
      );
    }

    const token = signCustomerJwt({
      id: customer.id,
      name: customer.name,
      email: customer.email,
      phone: customer.phone,
    });

    return NextResponse.json({
      status: 'success',
      message: 'Login berhasil.',
      data: {
        token,
        customer: {
          id: customer.id,
          name: customer.name,
          phone: customer.phone,
          phone_verified: Boolean(customer.phone_verified_at),
          email: customer.email,
          email_verified: Boolean(customer.email_verified_at),
        },
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
