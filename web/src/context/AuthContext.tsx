'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import { API_BASE_URL, CustomerUser } from '@/lib/api';

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

  useEffect(() => {
    const savedToken = localStorage.getItem('asf_customer_token');
    const savedUser = localStorage.getItem('asf_customer_user');

    if (savedToken && savedUser) {
      try {
        setToken(savedToken);
        setUser(JSON.parse(savedUser));
      } catch (e) {
        console.error('Error parsing stored customer user', e);
      }
    }
    setLoading(false);
  }, []);

  const login = (newToken: string, newUser: CustomerUser) => {
    setToken(newToken);
    setUser(newUser);
    localStorage.setItem('asf_customer_token', newToken);
    localStorage.setItem('asf_customer_user', JSON.stringify(newUser));
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem('asf_customer_token');
    localStorage.removeItem('asf_customer_user');
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
  };

  const refreshProfile = async () => {
    if (!token) return;
    try {
      const res = await fetch(`${API_BASE_URL}/auth/customer/profile`, {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
        },
      });
      if (res.ok) {
        const json = await res.json();
        setUser(json.data);
        localStorage.setItem('asf_customer_user', JSON.stringify(json.data));
      }
    } catch (err) {
      console.error('Failed to refresh profile', err);
    }
  };

  return (
    <AuthContext.Provider value={{ user, token, loading, login, logout, refreshProfile }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);

