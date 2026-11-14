import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { supabaseAdmin } from './supabase';

const JWT_SECRET = process.env.JWT_SECRET || 'santosa-farma-customer-secret-key-2026';

export interface CustomerPayload {
  id: number;
  name: string;
  email?: string | null;
  phone?: string | null;
}

export function signCustomerJwt(customer: CustomerPayload): string {
  return jwt.sign(
    {
      sub: customer.id,
      name: customer.name,
      email: customer.email,
      phone: customer.phone,
      role: 'customer',
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
}

export async function hashPassword(plain: string): Promise<string> {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(plain, salt);
}

export async function verifyPassword(plain: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plain, hash);
}

export async function getCustomerFromAuthHeader(req: Request): Promise<any | null> {
  const authHeader = req.headers.get('authorization') || req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.substring(7).trim();
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    if (!decoded || !decoded.sub) return null;

    const { data: customer, error } = await supabaseAdmin
      .from('customers')
      .select('*')
      .eq('id', decoded.sub)
      .maybeSingle();

    if (error || !customer) return null;
    return customer;
  } catch (err) {
    return null;
  }
}
