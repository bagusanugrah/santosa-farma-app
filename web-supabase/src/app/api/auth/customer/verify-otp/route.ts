import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import {
  getCustomerFromAuthHeader,
  signCustomerJwt,
  getPhoneVariants,
  findCustomerByContact,
  verifyRegistrationJwt,
} from '@/lib/server-auth';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { target, code, type, registration_token } = body;

    if (!target || !code || !type || !['phone', 'email'].includes(type)) {
      return NextResponse.json(
        { status: 'error', message: 'Target, kode OTP, dan tipe verifikasi wajib diisi.' },
        { status: 400 }
      );
    }

    const normalizedTarget =
      type === 'email' ? String(target).trim().toLowerCase() : String(target).trim();
    const cleanCode = String(code).trim();

    let otpQuery = supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('type', type)
      .eq('code', cleanCode)
      .is('verified_at', null)
      .gte('expires_at', new Date().toISOString())
      .order('id', { ascending: false })
      .limit(1);

    if (type === 'phone') {
      otpQuery = otpQuery.in('target', getPhoneVariants(normalizedTarget));
    } else {
      otpQuery = otpQuery.ilike('target', normalizedTarget);
    }

    const { data: validOtp } = await otpQuery.maybeSingle();

    if (!validOtp) {
      return NextResponse.json(
        { status: 'error', message: 'Kode OTP tidak valid atau sudah kadaluarsa.' },
        { status: 400 }
      );
    }

    const now = new Date().toISOString();
    let finalCustomer: any = null;

    if (registration_token && typeof registration_token === 'string') {
      // Flow registrasi baru: akun hanya dibuat SETELAH OTP lolos verifikasi
      const pendingReg = verifyRegistrationJwt(registration_token);
      if (!pendingReg || pendingReg.type !== type) {
        return NextResponse.json(
          { status: 'error', message: 'Token pendaftaran tidak valid atau telah kadaluarsa. Silakan daftar ulang.' },
          { status: 400 }
        );
      }

      const targetMatches =
        type === 'email'
          ? pendingReg.target.toLowerCase() === normalizedTarget
          : getPhoneVariants(normalizedTarget).includes(pendingReg.target);
      if (!targetMatches) {
        return NextResponse.json(
          { status: 'error', message: 'Target verifikasi OTP tidak sesuai dengan data pendaftaran.' },
          { status: 400 }
        );
      }

      const alreadyExists = await findCustomerByContact(type, pendingReg.target);
      if (alreadyExists) {
        return NextResponse.json(
          {
            status: 'error',
            message: `${type === 'phone' ? 'Nomor WhatsApp' : 'Alamat email'} sudah terdaftar. Silakan login.`,
          },
          { status: 422 }
        );
      }

      const newCustomerData: any = {
        name: pendingReg.name,
        password: pendingReg.passwordHash,
      };
      if (type === 'phone') {
        newCustomerData.phone = pendingReg.target;
        newCustomerData.phone_verified_at = now;
      } else {
        newCustomerData.email = pendingReg.target;
        newCustomerData.email_verified_at = now;
      }

      const { data: insertedCustomer, error: insertErr } = await supabaseAdmin
        .from('customers')
        .insert(newCustomerData)
        .select()
        .single();

      if (insertErr || !insertedCustomer) {
        return NextResponse.json(
          { status: 'error', message: insertErr?.message || 'Gagal menyelesaikan pembuatan akun.' },
          { status: 500 }
        );
      }

      finalCustomer = insertedCustomer;

      await supabaseAdmin
        .from('otp_codes')
        .update({ verified_at: now, customer_id: finalCustomer.id })
        .eq('id', validOtp.id);
    } else {
      // Flow akun existing (add-contact di profil atau login akun belum terverifikasi)
      let customer = await getCustomerFromAuthHeader(req);

      if (!customer && validOtp.customer_id) {
        const { data: c } = await supabaseAdmin
          .from('customers')
          .select('*')
          .eq('id', validOtp.customer_id)
          .maybeSingle();
        customer = c;
      }

      if (!customer) {
        customer = await findCustomerByContact(type, normalizedTarget);
      }

      if (!customer) {
        return NextResponse.json(
          { status: 'error', message: 'Sesi pendaftaran tidak ditemukan atau sudah berakhir. Silakan daftar ulang.' },
          { status: 404 }
        );
      }

      await supabaseAdmin
        .from('otp_codes')
        .update({ verified_at: now })
        .eq('id', validOtp.id);

      const updateData: any = { updated_at: now };
      if (type === 'phone') {
        updateData.phone = normalizedTarget;
        updateData.phone_verified_at = now;
      } else {
        updateData.email = normalizedTarget;
        updateData.email_verified_at = now;
      }

      const { data: updatedCustomer } = await supabaseAdmin
        .from('customers')
        .update(updateData)
        .eq('id', customer.id)
        .select()
        .single();

      finalCustomer = updatedCustomer || customer;
    }

    const token = signCustomerJwt({
      id: finalCustomer.id,
      name: finalCustomer.name,
      email: finalCustomer.email,
      phone: finalCustomer.phone,
    });

    return NextResponse.json({
      status: 'success',
      message: 'Verifikasi OTP berhasil.',
      data: {
        token,
        customer: {
          id: finalCustomer.id,
          name: finalCustomer.name,
          phone: finalCustomer.phone,
          phone_verified: Boolean(finalCustomer.phone_verified_at),
          email: finalCustomer.email,
          email_verified: Boolean(finalCustomer.email_verified_at),
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
