import { supabase } from './supabase';

export const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || '/api';

export function getProductImageUrl(image: string | null | undefined): string | null {
  if (!image) return null;
  if (image.startsWith('http://') || image.startsWith('https://')) {
    // If the image is on an ngrok-free domain, route it through Next.js image proxy
    if (image.includes('ngrok-free')) {
      return `/api/image-proxy?url=${encodeURIComponent(image)}`;
    }
    return image;
  }

  // Supabase public storage bucket
  const cleanPath = image.replace(/^products\//, '').replace(/^\//, '');
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://nykoitxkyyhwvtrndyrb.supabase.co';
  return `${supabaseUrl}/storage/v1/object/public/products/${cleanPath}`;
}

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

export interface StoreStatus {
  is_open: boolean;
  store_status: string;
  online_orders_enabled: boolean;
  is_online_active: boolean;
  last_opened_at?: string | null;
  last_closed_at?: string | null;
}

export async function fetchStoreStatus(): Promise<StoreStatus> {
  try {
    const { data, error } = await supabase
      .from('store_settings')
      .select('*')
      .eq('id', 1)
      .maybeSingle();

    if (error || !data) {
      console.warn('Failed to load store settings from Supabase, using default:', error);
      return {
        is_open: true,
        store_status: 'buka',
        online_orders_enabled: false,
        is_online_active: false,
      };
    }

    const isOpen = Boolean(data.is_open);
    const onlineOrdersEnabled = Boolean(data.online_orders_enabled);

    return {
      is_open: isOpen,
      store_status: isOpen ? 'buka' : 'tutup',
      online_orders_enabled: onlineOrdersEnabled,
      is_online_active: isOpen && onlineOrdersEnabled,
      last_opened_at: data.last_opened_at,
      last_closed_at: data.last_closed_at,
    };
  } catch (err) {
    console.error('Error fetching store status:', err);
    return {
      is_open: false,
      store_status: 'tutup',
      online_orders_enabled: false,
      is_online_active: false,
    };
  }
}

export async function fetchProducts(params: {
  search?: string;
  category?: string;
  sort?: string;
  per_page?: number;
  page?: number;
}): Promise<{ data: Product[]; meta: MetaPagination }> {
  try {
    const page = params.page && params.page > 0 ? params.page : 1;
    const perPage = params.per_page && params.per_page > 0 ? params.per_page : 10;
    const from = (page - 1) * perPage;
    const to = from + perPage - 1;

    let query = supabase
      .from('products')
      .select('*', { count: 'exact' });

    if (params.search && params.search.trim()) {
      query = query.ilike('name', `%${params.search.trim()}%`);
    }

    if (params.category && params.category !== 'all') {
      query = query.eq('category', params.category);
    }

    // Sort order
    if (params.sort === 'price_asc') {
      query = query.order('price', { ascending: true });
    } else if (params.sort === 'price_desc') {
      query = query.order('price', { ascending: false });
    } else if (params.sort === 'stock_desc') {
      query = query.order('stock', { ascending: false });
    } else {
      // Default A-Z
      query = query.order('name', { ascending: true });
    }

    query = query.range(from, to);

    const { data, count, error } = await query;
    if (error) {
      throw error;
    }

    const total = count ?? (data?.length || 0);
    const lastPage = Math.max(1, Math.ceil(total / perPage));

    const mappedProducts: Product[] = (data || []).map((item: any) => ({
      id: Number(item.id),
      name: item.name,
      price: Number(item.price),
      stock: Number(item.stock),
      image: item.image,
      image_url: getProductImageUrl(item.image),
      category: item.category,
      description: item.description,
    }));

    return {
      data: mappedProducts,
      meta: {
        current_page: page,
        per_page: perPage,
        total,
        last_page: lastPage,
        from: total > 0 ? from + 1 : null,
        to: total > 0 ? Math.min(to + 1, total) : null,
      },
    };
  } catch (err) {
    console.error('Error fetching products from Supabase:', err);
    return {
      data: [],
      meta: {
        current_page: 1,
        per_page: params.per_page || 10,
        total: 0,
        last_page: 1,
        from: null,
        to: null,
      },
    };
  }
}
