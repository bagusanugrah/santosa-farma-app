import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { getCustomerFromAuthHeader } from '@/lib/server-auth';

export async function GET(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json({ status: 'error', message: 'Unauthenticated.' }, { status: 401 });
    }

    return NextResponse.json({
      status: 'success',
      data: {
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        phone_verified: Boolean(customer.phone_verified_at),
        email: customer.email,
        email_verified: Boolean(customer.email_verified_at),
        created_at: customer.created_at,
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}

export async function PUT(req: Request) {
  try {
    const customer = await getCustomerFromAuthHeader(req);
    if (!customer) {
      return NextResponse.json({ status: 'error', message: 'Unauthenticated.' }, { status: 401 });
    }

    const body = await req.json();
    const { name } = body;

    if (!name || !name.trim()) {
      return NextResponse.json(
        { status: 'error', message: 'Nama tidak boleh kosong.' },
        { status: 422 }
      );
    }

    const { data: updated, error } = await supabaseAdmin
      .from('customers')
      .update({ name: name.trim(), updated_at: new Date().toISOString() })
      .eq('id', customer.id)
      .select()
      .single();

    if (error || !updated) {
      return NextResponse.json(
        { status: 'error', message: error?.message || 'Gagal memperbarui profil.' },
        { status: 500 }
      );
    }

    return NextResponse.json({
      status: 'success',
      message: 'Profil berhasil diperbarui.',
      data: {
        id: updated.id,
        name: updated.name,
        phone: updated.phone,
        phone_verified: Boolean(updated.phone_verified_at),
        email: updated.email,
        email_verified: Boolean(updated.email_verified_at),
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'error', message: err.message || 'Terjadi kesalahan server.' },
      { status: 500 }
    );
  }
}
