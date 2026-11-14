import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { verifyPassword, signCustomerJwt } from '@/lib/server-auth';

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

    // Phone variants
    const phoneVariants = [trimmedLogin];
    const cleanDigits = trimmedLogin.replace(/[^0-9]/g, '');
    if (cleanDigits) {
      if (cleanDigits.startsWith('0')) {
        phoneVariants.push('62' + cleanDigits.substring(1));
      } else if (cleanDigits.startsWith('62')) {
        phoneVariants.push('0' + cleanDigits.substring(2));
      }
      phoneVariants.push(cleanDigits);
    }

    let customer = null;
    if (isEmail) {
      const { data } = await supabaseAdmin
        .from('customers')
        .select('*')
        .ilike('email', trimmedLogin)
        .maybeSingle();
      customer = data;
    } else {
      const { data } = await supabaseAdmin
        .from('customers')
        .select('*')
        .in('phone', phoneVariants)
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

    // Check verification status
    if (isEmail && !customer.email_verified_at) {
      return NextResponse.json(
        {
          status: 'error',
          message: 'Email belum diverifikasi. Silakan masukkan kode OTP.',
          require_verification: true,
          target: customer.email,
          type: 'email',
        },
        { status: 403 }
      );
    }

    if (!isEmail && !customer.phone_verified_at) {
      return NextResponse.json(
        {
          status: 'error',
          message: 'Nomor WhatsApp belum diverifikasi. Silakan masukkan kode OTP.',
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
