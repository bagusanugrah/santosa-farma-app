import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://nykoitxkyyhwvtrndyrb.supabase.co';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'sb_publishable_c2EG8EOdDmUiPDZkd1ymXg_nW5DIP-M';

// Standard client for public & authenticated frontend operations
export const supabase = createClient<any>(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

// Admin client for server-side trusted operations (e.g., Midtrans webhooks, automated stock deduction)
const supabaseServiceKey = process.env.SUPABASE_SECRET_KEY || '';
export const supabaseAdmin = createClient<any>(
  supabaseUrl,
  supabaseServiceKey || supabaseAnonKey,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }
);
