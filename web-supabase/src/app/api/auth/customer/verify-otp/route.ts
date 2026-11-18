import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader, signCustomerJwt, getPhoneVariants } from '@/lib/server-auth';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { target, code, type } = body;

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

    // Mark OTP as verified
    await supabaseAdmin
      .from('otp_codes')
      .update({ verified_at: new Date().toISOString() })
      .eq('id', validOtp.id);

    // Find customer: prefer logged-in customer (for add-contact), then validOtp.customer_id, then target match
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
      if (type === 'phone') {
        const { data } = await supabaseAdmin
          .from('customers')
          .select('*')
          .in('phone', getPhoneVariants(normalizedTarget))
          .limit(1)
          .maybeSingle();
        customer = data;
      } else {
        const { data } = await supabaseAdmin
          .from('customers')
          .select('*')
          .ilike('email', normalizedTarget)
          .limit(1)
          .maybeSingle();
        customer = data;
      }
    }

    if (!customer) {
      return NextResponse.json(
        { status: 'error', message: 'Akun pelanggan tidak ditemukan.' },
        { status: 404 }
      );
    }

    // Update verified timestamp
    const now = new Date().toISOString();
    const updateData: any = { updated_at: now };
    if (type === 'phone') {
      updateData.phone = normalizedTarget;
      updateData.phone_verified_at = now;
    } else {
      updateData.email = normalizedTarget;
      updateData.email_verified_at = now;
    }

    const { data: updatedCustomer, error: updateErr } = await supabaseAdmin
      .from('customers')
      .update(updateData)
      .eq('id', customer.id)
      .select()
      .single();

    const finalCustomer = updatedCustomer || customer;

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
