'use client';

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { fetchStoreStatus, setOnlineOrders } from '@/lib/api';
import { useStaffAuth } from './StaffAuthContext';

interface StoreStatusContextType {
  onlineOrdersEnabled: boolean;
  isOpen: boolean;
  toggling: boolean;
  toggleOnlineOrders: () => Promise<boolean>;
  refreshStatus: () => Promise<void>;
  statusMessage: string;
}

const StoreStatusContext = createContext<StoreStatusContextType>({
  onlineOrdersEnabled: false,
  isOpen: true,
  toggling: false,
  toggleOnlineOrders: async () => false,
  refreshStatus: async () => {},
  statusMessage: '',
});

export const StoreStatusProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { token, user } = useStaffAuth();
  const [onlineOrdersEnabled, setOnlineOrdersEnabled] = useState(false);
  const [isOpen, setIsOpen] = useState(true);
  const [toggling, setToggling] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');

  const refreshStatus = useCallback(async () => {
    try {
      const data = await fetchStoreStatus();
      setOnlineOrdersEnabled(Boolean(data.online_orders_enabled));
      setIsOpen(Boolean(data.is_open));
    } catch (e) {
      console.error('Failed to fetch store status', e);
    }
  }, []);

  useEffect(() => {
    if (user && token) {
      refreshStatus();
      const interval = setInterval(refreshStatus, 10000);
      return () => clearInterval(interval);
    }
  }, [user, token, refreshStatus]);

  const toggleOnlineOrders = async (): Promise<boolean> => {
    if (!token || toggling) return false;
    setToggling(true);
    try {
      const nextVal = !onlineOrdersEnabled;
      const res = await setOnlineOrders(token, nextVal);
      if (res.success && res.data) {
        setOnlineOrdersEnabled(res.data.online_orders_enabled);
        setStatusMessage(
          res.data.online_orders_enabled
            ? 'Pemesanan di Web DIAKTIFKAN!'
            : 'Pemesanan di Web DINONAKTIFKAN (Katalog Saja).'
        );
        setTimeout(() => setStatusMessage(''), 4000);
        return true;
      } else {
        alert(res.message || 'Gagal mengubah status pemesanan online.');
        return false;
      }
    } catch (err: any) {
      alert(err.message || 'Terjadi kesalahan sistem.');
      return false;
    } finally {
      setToggling(false);
    }
  };

  return (
    <StoreStatusContext.Provider
      value={{
        onlineOrdersEnabled,
        isOpen,
        toggling,
        toggleOnlineOrders,
        refreshStatus,
        statusMessage,
      }}
    >
      {children}
    </StoreStatusContext.Provider>
  );
};

export const useStoreStatus = () => useContext(StoreStatusContext);

