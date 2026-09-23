'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import { StaffUser } from '@/lib/api';

interface StaffAuthContextType {
  user: StaffUser | null;
  token: string | null;
  loading: boolean;
  login: (token: string, user: StaffUser) => void;
  logout: () => void;
}

const StaffAuthContext = createContext<StaffAuthContextType>({
  user: null,
  token: null,
  loading: true,
  login: () => {},
  logout: () => {},
});

export const StaffAuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<StaffUser | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const savedToken = localStorage.getItem('asf_staff_token');
    const savedUser = localStorage.getItem('asf_staff_user');

    if (savedToken && savedUser) {
      try {
        setToken(savedToken);
        setUser(JSON.parse(savedUser));
      } catch (e) {
        console.error('Error loading staff session', e);
      }
    }
    setLoading(false);
  }, []);

  const login = (newToken: string, newUser: StaffUser) => {
    setToken(newToken);
    setUser(newUser);
    localStorage.setItem('asf_staff_token', newToken);
    localStorage.setItem('asf_staff_user', JSON.stringify(newUser));
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem('asf_staff_token');
    localStorage.removeItem('asf_staff_user');
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
  };

  return (
    <StaffAuthContext.Provider value={{ user, token, loading, login, logout }}>
      {children}
    </StaffAuthContext.Provider>
  );
};

export const useStaffAuth = () => useContext(StaffAuthContext);

