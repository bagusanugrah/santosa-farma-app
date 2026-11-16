import { supabaseAdmin } from './supabase';

export interface IntegrationSettings {
  fonnteToken: string;
  fonnteUrl: string;
  mailHost: string;
  mailPort: number;
  mailUser: string;
  mailPass: string;
  mailFromName: string;
  midtransClientKey: string;
  midtransServerKey: string;
  midtransIsProduction: boolean;
}

let cachedSettings: IntegrationSettings | null = null;
let lastFetchTime = 0;
const CACHE_TTL_MS = 60 * 1000; // 1-minute in-memory cache

export async function getIntegrationSettings(forceRefresh = false): Promise<IntegrationSettings> {
  const now = Date.now();
  if (!forceRefresh && cachedSettings && now - lastFetchTime < CACHE_TTL_MS) {
    return cachedSettings;
  }

  try {
    const { data } = await supabaseAdmin
      .from('store_settings')
      .select('*')
      .eq('id', 1)
      .maybeSingle();

    cachedSettings = {
      fonnteToken: data?.fonnte_token || process.env.WA_GATEWAY_TOKEN || '',
      fonnteUrl: data?.fonnte_url || process.env.WA_GATEWAY_URL || 'https://api.fonnte.com/send',
      mailHost: data?.mail_host || process.env.MAIL_HOST || 'smtp.gmail.com',
      mailPort: Number(data?.mail_port || process.env.MAIL_PORT || 587),
      mailUser: data?.mail_username || process.env.MAIL_USERNAME || 'kucitcloud@gmail.com',
      mailPass: data?.mail_password || process.env.MAIL_PASSWORD || '',
      mailFromName: data?.mail_from_name || process.env.MAIL_FROM_NAME || 'Apotek Santosa Farma',
      midtransClientKey:
        data?.midtrans_client_key ||
        process.env.NEXT_PUBLIC_MIDTRANS_CLIENT_KEY ||
        '',
      midtransServerKey:
        data?.midtrans_server_key ||
        process.env.MIDTRANS_SERVER_KEY ||
        '',
      midtransIsProduction:
        typeof data?.midtrans_is_production === 'boolean'
          ? data.midtrans_is_production
          : process.env.MIDTRANS_IS_PRODUCTION === 'true',
    };
    lastFetchTime = now;
    return cachedSettings;
  } catch (err) {
    console.error('[getIntegrationSettings error]', err);
    return {
      fonnteToken: process.env.WA_GATEWAY_TOKEN || '',
      fonnteUrl: process.env.WA_GATEWAY_URL || 'https://api.fonnte.com/send',
      mailHost: process.env.MAIL_HOST || 'smtp.gmail.com',
      mailPort: Number(process.env.MAIL_PORT || 587),
      mailUser: process.env.MAIL_USERNAME || 'kucitcloud@gmail.com',
      mailPass: process.env.MAIL_PASSWORD || '',
      mailFromName: process.env.MAIL_FROM_NAME || 'Apotek Santosa Farma',
      midtransClientKey:
        process.env.NEXT_PUBLIC_MIDTRANS_CLIENT_KEY || '',
      midtransServerKey:
        process.env.MIDTRANS_SERVER_KEY || '',
      midtransIsProduction: process.env.MIDTRANS_IS_PRODUCTION === 'true',
    };
  }
}
