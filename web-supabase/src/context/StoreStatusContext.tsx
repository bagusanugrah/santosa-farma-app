'use client';

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { fetchStoreStatus, StoreStatus } from '@/lib/api';
import { supabase } from '@/lib/supabase';

interface StoreStatusContextType {
  status: StoreStatus;
  isOpen: boolean;
  onlineOrdersEnabled: boolean;
  refreshStatus: () => Promise<void>;
}

const defaultStatus: StoreStatus = {
  is_open: true,
  store_status: 'buka',
  online_orders_enabled: false,
  is_online_active: false,
};

const StoreStatusContext = createContext<StoreStatusContextType>({
  status: defaultStatus,
  isOpen: true,
  onlineOrdersEnabled: false,
  refreshStatus: async () => {},
});

export const StoreStatusProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [status, setStatus] = useState<StoreStatus>(defaultStatus);

  const refreshStatus = useCallback(async () => {
    try {
      const data = await fetchStoreStatus();
      setStatus(data);
    } catch (err) {
      console.error('Failed to update store status', err);
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
            const onlineOrders = Boolean(payload.new.online_orders_enabled);
            setStatus({
              is_open: isOpen,
              store_status: isOpen ? 'buka' : 'tutup',
              online_orders_enabled: onlineOrders,
              is_online_active: isOpen && onlineOrders,
              last_opened_at: payload.new.last_opened_at,
              last_closed_at: payload.new.last_closed_at,
            });
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
        refreshStatus,
      }}
    >
      {children}
    </StoreStatusContext.Provider>
  );
};

export const useStoreStatus = () => useContext(StoreStatusContext);
