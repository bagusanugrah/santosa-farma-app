'use client';

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { fetchStoreStatus, StoreStatus } from '@/lib/api';
import { supabase } from '@/lib/supabase';

interface StoreStatusContextType {
  status: StoreStatus;
  isOpen: boolean;
  onlineOrdersEnabled: boolean;
  hasMidtrans: boolean;
  loading: boolean;
  storeAddress: string;
  storePhone: string;
  midtransClientKey: string;
  midtransIsProduction: boolean;
  refreshStatus: () => Promise<void>;
}

const defaultStatus: StoreStatus = {
  is_open: true,
  store_status: 'buka',
  online_orders_enabled: false,
  is_online_active: false,
  has_midtrans: (process.env.NEXT_PUBLIC_MIDTRANS_CLIENT_KEY || '').length >= 15,
  store_address: '',
  store_phone: '',
  midtrans_client_key: process.env.NEXT_PUBLIC_MIDTRANS_CLIENT_KEY || '',
  midtrans_is_production: false,
};

const StoreStatusContext = createContext<StoreStatusContextType>({
  status: defaultStatus,
  isOpen: true,
  onlineOrdersEnabled: false,
  hasMidtrans: false,
  loading: true,
  storeAddress: '',
  storePhone: '',
  midtransClientKey: process.env.NEXT_PUBLIC_MIDTRANS_CLIENT_KEY || '',
  midtransIsProduction: false,
  refreshStatus: async () => {},
});

export const StoreStatusProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [status, setStatus] = useState<StoreStatus>(defaultStatus);
  const [loading, setLoading] = useState<boolean>(true);

  const refreshStatus = useCallback(async () => {
    try {
      const data = await fetchStoreStatus();
      setStatus(data);
    } catch (err) {
      console.error('Failed to update store status', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refreshStatus();

    // 1. Supabase Realtime Subscription for zero-latency status toggle from Android Kasir
    const channel = supabase
      .channel('store-status-channel')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'store_settings' },
        (payload: any) => {
          if (payload.new) {
            const isOpen = Boolean(payload.new.is_open);
            setStatus((prev) => {
              const clientKey = (payload.new.midtrans_client_key ?? prev.midtrans_client_key ?? '').trim();
              const hasMidtrans = clientKey.length >= 15;
              const onlineOrders = Boolean(payload.new.online_orders_enabled);

              return {
                is_open: isOpen,
                store_status: isOpen ? 'buka' : 'tutup',
                online_orders_enabled: onlineOrders,
                is_online_active: isOpen && onlineOrders,
                has_midtrans: hasMidtrans,
                last_opened_at: payload.new.last_opened_at,
                last_closed_at: payload.new.last_closed_at,
                store_address:
                  typeof payload.new.store_address === 'string'
                    ? payload.new.store_address.trim()
                    : prev.store_address || '',
                store_phone:
                  typeof payload.new.store_phone === 'string'
                    ? payload.new.store_phone.trim()
                    : prev.store_phone || '',
                midtrans_client_key: clientKey,
                midtrans_is_production:
                  typeof payload.new.midtrans_is_production === 'boolean'
                    ? payload.new.midtrans_is_production
                    : prev.midtrans_is_production,
              };
            });
            setLoading(false);
          } else {
            refreshStatus();
          }
        }
      )
      .subscribe();

    // 2. Fallback polling every 10 seconds
    const interval = setInterval(refreshStatus, 10000);

    // 3. Re-check immediately when tab gains focus
    const onFocus = () => refreshStatus();
    window.addEventListener('focus', onFocus);
    window.addEventListener('visibilitychange', onFocus);

    return () => {
      supabase.removeChannel(channel);
      clearInterval(interval);
      window.removeEventListener('focus', onFocus);
      window.removeEventListener('visibilitychange', onFocus);
    };
  }, [refreshStatus]);

  return (
    <StoreStatusContext.Provider
      value={{
        status,
        isOpen: status.is_open,
        onlineOrdersEnabled: status.online_orders_enabled,
        hasMidtrans: Boolean(status.has_midtrans ?? ((status.midtrans_client_key || '').length >= 15)),
        loading,
        storeAddress: (status.store_address || '').trim(),
        storePhone: (status.store_phone || '').trim(),
        midtransClientKey:
          status.midtrans_client_key || process.env.NEXT_PUBLIC_MIDTRANS_CLIENT_KEY || '',
        midtransIsProduction: Boolean(status.midtrans_is_production),
        refreshStatus,
      }}
    >
      {children}
    </StoreStatusContext.Provider>
  );
};

export const useStoreStatus = () => useContext(StoreStatusContext);
