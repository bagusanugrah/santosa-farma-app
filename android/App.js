import React, { useState } from 'react';
import { SafeAreaView, View, Text, TouchableOpacity, StatusBar } from 'react-native';
import LoginScreen from './src/screens/LoginScreen';
import ShowQrisScreen from './src/screens/ShowQrisScreen';
import ScanPickupScreen from './src/screens/ScanPickupScreen';
import { setToken } from './src/services/api';

export default function App() {
  const [currentUser, setCurrentUser] = useState(null);
  const [activeTab, setActiveTab] = useState('qris'); // 'qris' | 'scan'

  const handleLogout = () => {
    setToken(null);
    setCurrentUser(null);
  };

  if (!currentUser) {
    return (
      <SafeAreaView className="flex-1 bg-slate-900">
        <StatusBar barStyle="light-content" backgroundColor="#0f172a" />
        <LoginScreen onLoginSuccess={(user) => setCurrentUser(user)} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-slate-900">
      <StatusBar barStyle="light-content" backgroundColor="#0f172a" />

      {/* Top App Bar */}
      <View className="bg-slate-800 px-4 py-3 border-b border-slate-700 flex-row items-center justify-between">
        <View className="flex-row items-center space-x-2">
          <View className="w-8 h-8 rounded-xl bg-emerald-500 items-center justify-center">
            <Text className="text-slate-950 font-black text-sm">✚</Text>
          </View>
          <View>
            <Text className="text-xs font-black text-white">Apotek Santosa Farma</Text>
            <Text className="text-[10px] text-emerald-400 font-bold">Kasir: {currentUser.name}</Text>
          </View>
        </View>

        <TouchableOpacity
          onPress={handleLogout}
          className="bg-red-500/20 px-3 py-1.5 rounded-lg border border-red-500/30"
        >
          <Text className="text-red-400 font-bold text-[10px]">Logout</Text>
        </TouchableOpacity>
      </View>

      {/* Screen Body */}
      <View className="flex-1">
        {activeTab === 'qris' ? <ShowQrisScreen /> : <ScanPickupScreen />}
      </View>

      {/* Bottom Tab Bar */}
      <View className="bg-slate-800 border-t border-slate-700 flex-row p-2">
        <TouchableOpacity
          onPress={() => setActiveTab('qris')}
          className={`flex-1 py-2.5 rounded-2xl items-center justify-center ${
            activeTab === 'qris' ? 'bg-emerald-500 shadow-md' : 'bg-transparent'
          }`}
        >
          <Text
            className={`text-xs font-black ${
              activeTab === 'qris' ? 'text-slate-950' : 'text-slate-400'
            }`}
          >
            📱 Tampilkan QRIS
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          onPress={() => setActiveTab('scan')}
          className={`flex-1 py-2.5 rounded-2xl items-center justify-center ${
            activeTab === 'scan' ? 'bg-emerald-500 shadow-md' : 'bg-transparent'
          }`}
        >
          <Text
            className={`text-xs font-black ${
              activeTab === 'scan' ? 'text-slate-950' : 'text-slate-400'
            }`}
          >
            📷 Scan QR Pesanan
          </Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

