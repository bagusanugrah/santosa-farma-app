'use client';

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { API_BASE_URL, CustomerUser } from '@/lib/api';
import { supabase } from '@/lib/supabase';

interface AuthContextType {
  user: CustomerUser | null;
  token: string | null;
  loading: boolean;
  login: (token: string, user: CustomerUser) => void;
  logout: () => void;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  token: null,
  loading: true,
  login: () => {},
  logout: () => {},
  refreshProfile: async () => {},
});

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<CustomerUser | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const clearSession = useCallback(() => {
    setToken(null);
    setUser(null);
    if (typeof window !== 'undefined') {
      localStorage.removeItem('asf_customer_token');
      localStorage.removeItem('asf_customer_user');
    }
  }, []);

  // Check directly via Supabase whether customer row still exists (zero Vercel Serverless calls)
  const checkAccountExistsDirect = useCallback(
    async (targetUserId: number): Promise<boolean> => {
      try {
        const { data: row, error } = await supabase
          .from('customers')
          .select('id, name, phone, phone_verified_at, email, email_verified_at')
          .eq('id', targetUserId)
          .maybeSingle();

        if (!error && !row) {
          clearSession();
          return false;
        }
        if (!error && row) {
          const verifiedUser: CustomerUser = {
            id: row.id,
            name: row.name,
            phone: row.phone,
            phone_verified: Boolean(row.phone_verified_at),
            email: row.email,
            email_verified: Boolean(row.email_verified_at),
          };
          setUser(verifiedUser);
          localStorage.setItem('asf_customer_user', JSON.stringify(verifiedUser));
          return true;
        }
      } catch (_) {}
      return true;
    },
    [clearSession]
  );

  const verifySession = useCallback(
    async (activeToken: string, fallbackUserId?: number | null): Promise<boolean> => {
      try {
        const res = await fetch(`${API_BASE_URL}/auth/customer/profile?_t=${Date.now()}`, {
          cache: 'no-store',
          headers: {
            Authorization: `Bearer ${activeToken}`,
            Accept: 'application/json',
          },
        });

        if (res.status === 401 || res.status === 403 || res.status === 404) {
          clearSession();
          return false;
        }

        if (res.ok) {
          const json = await res.json();
          if (json?.data?.id) {
            setToken((prev) => (prev === activeToken ? prev : activeToken));
            setUser(json.data);
            localStorage.setItem('asf_customer_user', JSON.stringify(json.data));
            return true;
          }
          clearSession();
          return false;
        }
      } catch (err) {
        console.error('Failed to verify customer session via API', err);
      }

      if (fallbackUserId) {
        return checkAccountExistsDirect(fallbackUserId);
      }

      return false;
    },
    [clearSession, checkAccountExistsDirect]
  );

  useEffect(() => {
    let active = true;

    const initSession = async () => {
      const savedToken = localStorage.getItem('asf_customer_token');
      const savedUserRaw = localStorage.getItem('asf_customer_user');

      if (!savedToken || !savedUserRaw) {
        clearSession();
        if (active) setLoading(false);
        return;
      }

      try {
        const parsedUser = JSON.parse(savedUserRaw) as CustomerUser;
        await verifySession(savedToken, parsedUser?.id);
      } catch (e) {
        console.error('Error parsing stored customer user', e);
        clearSession();
      } finally {
        if (active) setLoading(false);
      }
    };

    initSession();

    return () => {
      active = false;
    };
  }, [clearSession, verifySession]);

  // Event-driven guard on tab focus & realtime DB changes (no background polling, zero extra Vercel load)
  const userId = user?.id;
  useEffect(() => {
    if (!token || !userId) return;

    const recheckDirect = () => {
      checkAccountExistsDirect(userId);
    };

    const onVisibilityOrFocus = () => {
      if (document.visibilityState === 'visible') {
        recheckDirect();
      }
    };

    window.addEventListener('focus', recheckDirect);
    document.addEventListener('visibilitychange', onVisibilityOrFocus);

    const channel = supabase
      .channel(`customer-session-guard-${userId}`)
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'customers', filter: `id=eq.${userId}` },
        () => {
          clearSession();
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'store_settings' },
        () => {
          // Factory reset updates store_settings; verify directly via Supabase without hitting Vercel
          recheckDirect();
        }
      )
      .subscribe();

    return () => {
      window.removeEventListener('focus', recheckDirect);
      document.removeEventListener('visibilitychange', onVisibilityOrFocus);
      supabase.removeChannel(channel);
    };
  }, [token, userId, checkAccountExistsDirect, clearSession]);

  const login = (newToken: string, newUser: CustomerUser) => {
    setToken(newToken);
    setUser(newUser);
    localStorage.setItem('asf_customer_token', newToken);
    localStorage.setItem('asf_customer_user', JSON.stringify(newUser));
  };

  const logout = () => {
    clearSession();
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
  };

  const refreshProfile = async () => {
    if (!token) return;
    await verifySession(token, user?.id);
  };

  return (
    <AuthContext.Provider value={{ user, token, loading, login, logout, refreshProfile }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);

