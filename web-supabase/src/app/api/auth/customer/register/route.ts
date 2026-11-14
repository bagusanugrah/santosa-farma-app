import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { hashPassword } from '@/lib/server-auth';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { name, type, phone, email, password } = body;

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
          message: 'Pendaftaran akun baru ditutup sementara karena kasir sedang menonaktifkan layanan online.',
        },
        { status: 403 }
      );
    }

    if (!name || !type || !password) {
      return NextResponse.json(
        { status: 'error', message: 'Nama, tipe registrasi, dan password wajib diisi.' },
        { status: 422 }
      );
    }

    const target = type === 'phone' ? phone?.trim() : email?.trim();
    if (!target) {
      return NextResponse.json(
        { status: 'error', message: `Field ${type} wajib diisi.` },
        { status: 422 }
      );
    }

    // Check uniqueness
    const field = type === 'phone' ? 'phone' : 'email';
    const { data: existing } = await supabaseAdmin
      .from('customers')
      .select('id')
      .eq(field, target)
      .maybeSingle();

    if (existing) {
      return NextResponse.json(
        {
          status: 'error',
          message: `${type === 'phone' ? 'Nomor WhatsApp' : 'Alamat email'} sudah terdaftar. Silakan login.`,
        },
        { status: 422 }
      );
    }

    const hashedPassword = await hashPassword(password);

    const newCustomerData: any = {
      name: name.trim(),
      password: hashedPassword,
    };
    if (type === 'phone') {
      newCustomerData.phone = target;
    } else {
      newCustomerData.email = target;
    }

    const { data: insertedCustomer, error: insertErr } = await supabaseAdmin
      .from('customers')
      .insert(newCustomerData)
      .select()
      .single();

    if (insertErr || !insertedCustomer) {
      return NextResponse.json(
        { status: 'error', message: insertErr?.message || 'Gagal membuat akun.' },
        { status: 500 }
      );
    }

    // Generate 6 digit OTP
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

    await supabaseAdmin.from('otp_codes').insert({
      customer_id: insertedCustomer.id,
      type,
      target,
      code,
      expires_at: expiresAt,
    });

    console.log(`[OTP Generated for ${target}]: ${code}`);

    return NextResponse.json(
      {
        status: 'success',
        message: `Registrasi berhasil. Kode OTP Anda adalah: ${code}`,
        data: {
          customer_id: insertedCustomer.id,
          target,
          type,
          debug_code: code,
        },
      },
      { status: 201 }
    );
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
