import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import {
  hashPassword,
  findCustomerByContact,
  signRegistrationJwt,
} from '@/lib/server-auth';
import { sendOtpNotification } from '@/lib/notifications';

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

    if (!name || !name.trim() || !type || !['phone', 'email'].includes(type) || !password) {
      return NextResponse.json(
        { status: 'error', message: 'Nama, tipe registrasi, dan password wajib diisi.' },
        { status: 422 }
      );
    }

    if (String(password).length < 6) {
      return NextResponse.json(
        { status: 'error', message: 'Password minimal 6 karakter.' },
        { status: 422 }
      );
    }

    const target = type === 'phone' ? phone?.trim() : email?.trim().toLowerCase();
    if (!target) {
      return NextResponse.json(
        { status: 'error', message: `Field ${type} wajib diisi.` },
        { status: 422 }
      );
    }

    // Check uniqueness (case-insensitive email or Indonesian phone variants)
    const existing = await findCustomerByContact(type, target);
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

    // Generate 6 digit OTP WITHOUT inserting into `customers` yet.
    // Akun baru hanya dibuat di database setelah OTP berhasil diverifikasi.
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

    const { data: insertedOtp, error: otpErr } = await supabaseAdmin
      .from('otp_codes')
      .insert({
        customer_id: null,
        type,
        target,
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

    // Send actual WhatsApp or Email message; rollback OTP if delivery failed
    const sent = await sendOtpNotification(target, type, code);
    if (!sent) {
      await supabaseAdmin.from('otp_codes').delete().eq('id', insertedOtp.id);
      return NextResponse.json(
        {
          status: 'error',
          message:
            type === 'phone'
              ? 'Gagal mengirim kode OTP ke WhatsApp. Pastikan nomor aktif dan gateway WhatsApp sudah dikonfigurasi.'
              : 'Gagal mengirim kode OTP ke Email. Pastikan alamat email valid dan konfigurasi email aktif.',
        },
        { status: 502 }
      );
    }

    const registrationToken = signRegistrationJwt({
      name: name.trim(),
      type,
      target,
      passwordHash: hashedPassword,
    });

    return NextResponse.json(
      {
        status: 'success',
        message: `Kode OTP telah dikirimkan ke ${type === 'phone' ? 'WhatsApp' : 'email'} ${target}. Verifikasi OTP untuk menyelesaikan pendaftaran.`,
        data: {
          registration_token: registrationToken,
          target,
          type,
        },
      },
      { status: 200 }
    );
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
