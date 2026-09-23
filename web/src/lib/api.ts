export const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api';

export interface Product {
  id: number;
  name: string;
  price: number;
  stock: number;
  image: string | null;
  image_url: string | null;
  category: string | null;
  description: string | null;
}

export interface MetaPagination {
  current_page: number;
  per_page: number;
  total: number;
  last_page: number;
  from: number | null;
  to: number | null;
}

export interface CustomerUser {
  id: number;
  name: string;
  phone: string | null;
  phone_verified: boolean;
  email: string | null;
  email_verified: boolean;
}

export interface TransactionItem {
  id: number;
  transaction_id: number;
  product_id: number;
  product_name: string;
  qty: number;
  price: number;
  subtotal: number;
}

export interface Transaction {
  id: number;
  invoice_no: string;
  channel: 'toko' | 'online';
  payment_method: 'tunai' | 'qris' | 'kartu' | 'va';
  midtrans_order_id: string | null;
  midtrans_snap_token: string | null;
  midtrans_qris_url: string | null;
  midtrans_va_number: string | null;
  status: 'pending' | 'paid' | 'diambil' | 'selesai' | 'expired' | 'gagal';
  total: number;
  qr_token: string | null;
  paid_at: string | null;
  picked_up_at: string | null;
  created_at: string;
  items?: TransactionItem[];
}

export async function fetchStoreStatus(): Promise<{ is_open: boolean; store_status: string }> {
  try {
    const res = await fetch(`${API_BASE_URL}/store/status`, { cache: 'no-store' });
    if (!res.ok) throw new Error('Status fetch failed');
    const data = await res.json();
    return data.data;
  } catch (err) {
    return { is_open: false, store_status: 'tutup' };
  }
}

export async function fetchProducts(params: {
  search?: string;
  category?: string;
  sort?: string;
  per_page?: number;
  page?: number;
}): Promise<{ data: Product[]; meta: MetaPagination }> {
  const query = new URLSearchParams();
  if (params.search) query.append('search', params.search);
  if (params.category && params.category !== 'all') query.append('category', params.category);
  if (params.sort) query.append('sort', params.sort);
  if (params.per_page) query.append('per_page', params.per_page.toString());
  if (params.page) query.append('page', params.page.toString());

  const res = await fetch(`${API_BASE_URL}/products?${query.toString()}`, { cache: 'no-store' });
  if (!res.ok) throw new Error('Failed to fetch products');
  return res.json();
}

