import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from 'react-native';
import { loginStaff, setToken, setBaseUrl, getBaseUrl } from '../services/api';

export default function LoginScreen({ onLoginSuccess }) {
  const [serverUrl, setServerUrl] = useState(getBaseUrl());
  const [username, setUsername] = useState('kasir');
  const [password, setPassword] = useState('password123');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showServerSetting, setShowServerSetting] = useState(false);

  const handleLogin = async () => {
    if (!username || !password) {
      setError('Harap masukkan username dan password.');
      return;
    }

    setLoading(true);
    setError('');
    setBaseUrl(serverUrl.trim());

    try {
      const res = await loginStaff(username.trim(), password);
      if (res.data && res.data.token) {
        setToken(res.data.token);
        onLoginSuccess(res.data.user);
      }
    } catch (err) {
      setError(err.message || 'Login gagal. Periksa koneksi atau kredensial.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      className="flex-1 bg-slate-900 justify-center p-6"
    >
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center' }}>
        <View className="bg-slate-800 rounded-3xl p-6 border border-slate-700 shadow-2xl">
          {/* Header */}
          <View className="items-center mb-6">
            <View className="w-16 h-16 rounded-2xl bg-emerald-500 items-center justify-center mb-3 shadow-lg shadow-emerald-500/30">
              <Text className="text-3xl font-black text-slate-950">✚</Text>
            </View>
            <Text className="text-2xl font-black text-white text-center">Santosa Farma Kasir</Text>
            <Text className="text-xs text-slate-400 mt-1 text-center">
              Aplikasi Pendamping Kasir (QRIS & Scan QR)
            </Text>
          </View>

          {error ? (
            <View className="bg-red-500/20 border border-red-500/40 p-3 rounded-2xl mb-4">
              <Text className="text-xs text-red-300 font-semibold text-center">{error}</Text>
            </View>
          ) : null}

          {/* Form */}
          <View className="space-y-4">
            <View>
              <Text className="text-xs font-bold text-slate-300 mb-1">Username Kasir</Text>
              <TextInput
                value={username}
                onChangeText={setUsername}
                placeholder="kasir atau admin"
                placeholderTextColor="#64748b"
                autoCapitalize="none"
                className="bg-slate-900 border border-slate-700 text-white rounded-xl px-4 py-3 text-sm font-medium"
              />
            </View>

            <View>
              <Text className="text-xs font-bold text-slate-300 mb-1">Password</Text>
              <TextInput
                value={password}
                onChangeText={setPassword}
                placeholder="••••••••"
                placeholderTextColor="#64748b"
                secureTextEntry
                className="bg-slate-900 border border-slate-700 text-white rounded-xl px-4 py-3 text-sm font-medium"
              />
            </View>

            {/* Optional Server URL Setting */}
            <TouchableOpacity
              onPress={() => setShowServerSetting(!showServerSetting)}
              className="py-1"
            >
              <Text className="text-[11px] text-emerald-400 font-bold text-right">
                {showServerSetting ? 'Sembunyikan URL Server' : '⚙ Pengaturan URL Server API'}
              </Text>
            </TouchableOpacity>

            {showServerSetting && (
              <View className="bg-slate-950/60 p-3 rounded-xl border border-slate-700">
                <Text className="text-[10px] text-slate-400 mb-1">URL API Backend (Ngrok / Lokal):</Text>
                <TextInput
                  value={serverUrl}
                  onChangeText={setServerUrl}
                  placeholder="https://xxx.ngrok-free.app/api"
                  placeholderTextColor="#64748b"
                  autoCapitalize="none"
                  className="bg-slate-900 border border-slate-800 text-slate-200 rounded-lg px-2.5 py-1.5 text-xs font-mono"
                />
              </View>
            )}

            <TouchableOpacity
              onPress={handleLogin}
              disabled={loading}
              className="bg-emerald-500 active:bg-emerald-600 rounded-xl py-3.5 items-center justify-center mt-2 shadow-lg shadow-emerald-500/20"
            >
              {loading ? (
                <ActivityIndicator color="#0f172a" />
              ) : (
                <Text className="text-slate-950 font-black text-sm">Masuk Kasir</Text>
              )}
            </TouchableOpacity>
          </View>

          <Text className="text-center text-[10px] text-slate-500 mt-6">
            Apotek Santosa Farma — Jalancagak, Subang
          </Text>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

