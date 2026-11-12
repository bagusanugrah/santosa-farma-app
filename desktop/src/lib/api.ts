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

export interface StaffUser {
  id: number;
  name: string;
  username: string;
  role: 'super_admin' | 'admin_kasir';
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
  status: 'pending' | 'paid' | 'diambil' | 'selesai' | 'expired' | 'gagal';
  total: number;
  amount_paid: number | null;
  change_amount: number | null;
  qr_token: string | null;
  paid_at: string | null;
  picked_up_at: string | null;
  created_at: string;
  customer?: { id: number; name: string; phone: string | null; email: string | null };
  cashier?: { id: number; name: string; username: string };
  items?: TransactionItem[];
}

export interface StoreStatus {
  is_open: boolean;
  store_status: string;
  online_orders_enabled: boolean;
  is_online_active: boolean;
  last_opened_at: string | null;
  last_closed_at: string | null;
}

export async function fetchStoreStatus(): Promise<StoreStatus> {
  try {
    const res = await fetch(`${API_BASE_URL}/store/status`, { cache: 'no-store' });
    if (!res.ok) throw new Error('Failed to fetch store status');
    const json = await res.json();
    return json.data;
  } catch (err) {
    return {
      is_open: false,
      store_status: 'tutup',
      online_orders_enabled: false,
      is_online_active: false,
      last_opened_at: null,
      last_closed_at: null,
    };
  }
}

export async function setOnlineOrders(token: string, enabled?: boolean): Promise<{ success: boolean; data?: StoreStatus; message?: string }> {
  try {
    const res = await fetch(`${API_BASE_URL}/store/online-orders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(typeof enabled === 'boolean' ? { enabled } : {}),
    });
    const json = await res.json();
    if (!res.ok) throw new Error(json.message || 'Gagal mengubah status pemesanan online.');
    return { success: true, data: json.data, message: json.message };
  } catch (err: any) {
    return { success: false, message: err.message };
  }
}

export async function changeStaffPassword(
  token: string,
  payload: {
    current_password: string;
    new_password: string;
    new_password_confirmation: string;
  }
): Promise<{ success: boolean; message: string }> {
  try {
    const res = await fetch(`${API_BASE_URL}/auth/staff/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(payload),
    });
    const json = await res.json();
    if (!res.ok) {
      const errDetail = json.errors ? Object.values(json.errors)[0] as string : null;
      throw new Error(errDetail || json.message || 'Gagal mengubah password.');
    }
    return { success: true, message: json.message || 'Password berhasil diperbarui.' };
  } catch (err: any) {
    return { success: false, message: err.message };
  }
}


