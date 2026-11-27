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

export interface PendingRegistrationPayload {
  name: string;
  type: 'phone' | 'email';
  target: string;
  passwordHash: string;
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

export function signRegistrationJwt(payload: PendingRegistrationPayload): string {
  return jwt.sign(
    {
      ...payload,
      purpose: 'pending_registration',
    },
    JWT_SECRET,
    { expiresIn: '30m' }
  );
}

export function verifyRegistrationJwt(token: string): PendingRegistrationPayload | null {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    if (
      !decoded ||
      decoded.purpose !== 'pending_registration' ||
      !decoded.name ||
      !decoded.target ||
      !decoded.passwordHash ||
      (decoded.type !== 'phone' && decoded.type !== 'email')
    ) {
      return null;
    }
    return {
      name: String(decoded.name),
      type: decoded.type,
      target: String(decoded.target),
      passwordHash: String(decoded.passwordHash),
    };
  } catch {
    return null;
  }
}

export async function findCustomerByContact(type: 'phone' | 'email', target: string): Promise<any | null> {
  if (type === 'phone') {
    const { data } = await supabaseAdmin
      .from('customers')
      .select('*')
      .in('phone', getPhoneVariants(target))
      .limit(1)
      .maybeSingle();
    return data || null;
  }
  const { data } = await supabaseAdmin
    .from('customers')
    .select('*')
    .ilike('email', target)
    .limit(1)
    .maybeSingle();
  return data || null;
}

export async function hashPassword(plain: string): Promise<string> {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(plain, salt);
}

export async function verifyPassword(plain: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plain, hash);
}

export function getPhoneVariants(rawPhone: string): string[] {
  const trimmed = rawPhone.trim();
  const variants = new Set<string>([trimmed]);
  const cleanDigits = trimmed.replace(/[^0-9]/g, '');
  if (cleanDigits) {
    variants.add(cleanDigits);
    if (cleanDigits.startsWith('0')) {
      variants.add('62' + cleanDigits.substring(1));
      variants.add('+62' + cleanDigits.substring(1));
    } else if (cleanDigits.startsWith('62')) {
      variants.add('0' + cleanDigits.substring(2));
      variants.add('+' + cleanDigits);
    }
  }
  return Array.from(variants);
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
