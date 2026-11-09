'use client';

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { fetchStoreStatus, StoreStatus } from '@/lib/api';

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

    // Fast polling every 5 seconds for real-time reactivity when cashier toggles
    const interval = setInterval(refreshStatus, 5000);

    // Re-check immediately when tab gains focus
    const onFocus = () => refreshStatus();
    window.addEventListener('focus', onFocus);
    window.addEventListener('visibilitychange', onFocus);

    return () => {
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

