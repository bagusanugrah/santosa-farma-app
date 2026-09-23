// Base URL pointing to local server or ngrok static domain
export const DEFAULT_API_URL = 'http://10.0.2.2:8000/api'; // 10.0.2.2 for Android Emulator, or ngrok static domain

let currentBaseUrl = DEFAULT_API_URL;
let currentToken = null;

export const setBaseUrl = (url) => {
  currentBaseUrl = url.endsWith('/') ? url.slice(0, -1) : url;
};

export const getBaseUrl = () => currentBaseUrl;

export const setToken = (token) => {
  currentToken = token;
};

export const apiFetch = async (endpoint, options = {}) => {
  const headers = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    ...(currentToken ? { Authorization: `Bearer ${currentToken}` } : {}),
    ...(options.headers || {}),
  };

  const url = `${currentBaseUrl}${endpoint}`;
  const response = await fetch(url, {
    ...options,
    headers,
  });

  const json = await response.json();
  if (!response.ok) {
    throw new Error(json.message || `Request failed with status ${response.status}`);
  }
  return json;
};

export const loginStaff = async (username, password) => {
  return apiFetch('/auth/staff/login', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
};

export const getActiveQris = async () => {
  return apiFetch('/transactions/pos/active-qris');
};

export const getOrderByQr = async (qrToken) => {
  return apiFetch(`/transactions/qr/${encodeURIComponent(qrToken)}`);
};

export const confirmOrderPickup = async (qrToken) => {
  return apiFetch(`/transactions/pickup/${encodeURIComponent(qrToken)}`, {
    method: 'POST',
  });
};

