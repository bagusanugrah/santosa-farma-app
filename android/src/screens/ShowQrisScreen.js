import React, { useState, useEffect } from 'react';
import { View, Text, Image, ActivityIndicator, TouchableOpacity, ScrollView } from 'react-native';
import { getActiveQris } from '../services/api';

export default function ShowQrisScreen() {
  const [activeTrx, setActiveTrx] = useState(null);
  const [loading, setLoading] = useState(true);
  const [lastCheck, setLastCheck] = useState(new Date());

  const fetchQris = async () => {
    try {
      const res = await getActiveQris();
      setActiveTrx(res.data);
      setLastCheck(new Date());
    } catch (err) {
      console.warn('Error polling active QRIS:', err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchQris();
    const interval = setInterval(fetchQris, 2500); // Poll every 2.5s
    return () => clearInterval(interval);
  }, []);

  if (loading && !activeTrx) {
    return (
      <View className="flex-1 bg-slate-900 items-center justify-center p-6">
        <ActivityIndicator size="large" color="#10b981" />
        <Text className="text-xs text-slate-400 mt-3 font-medium">
          Menghubungkan ke POS Kasir...
        </Text>
      </View>
    );
  }

  return (
    <ScrollView className="flex-1 bg-slate-900 p-4">
      <View className="items-center py-2 mb-2">
        <Text className="text-lg font-black text-white">QRIS Kasir Santosa Farma</Text>
        <Text className="text-[11px] text-slate-400">
          Layar Tampilan Pembayaran QRIS Pelanggan
        </Text>
      </View>

      {activeTrx ? (
        <View className="bg-white rounded-3xl p-6 items-center shadow-2xl space-y-4 border border-slate-200">
          <View className="bg-emerald-100 px-3 py-1 rounded-full">
            <Text className="text-emerald-800 text-xs font-bold uppercase">
              Silakan Scan QRIS di Bawah
            </Text>
          </View>

          {/* QRIS Image */}
          <View className="p-3 bg-white border-2 border-dashed border-slate-300 rounded-2xl shadow-sm">
            {activeTrx.midtrans_qris_url ? (
              <Image
                source={{ uri: activeTrx.midtrans_qris_url }}
                style={{ width: 230, height: 230 }}
                resizeMode="contain"
              />
            ) : (
              <View className="w-56 h-56 bg-slate-100 items-center justify-center rounded-xl">
                <Text className="text-xs font-bold text-slate-500">QR Code Memuat...</Text>
              </View>
            )}
          </View>

          {/* Transaction Info */}
          <View className="w-full bg-slate-50 p-4 rounded-2xl border border-slate-100 space-y-1.5">
            <View className="flex-row justify-between">
              <Text className="text-xs text-slate-500">No. Invoice:</Text>
              <Text className="text-xs font-bold text-slate-800">{activeTrx.invoice_no}</Text>
            </View>
            <View className="flex-row justify-between items-center pt-2 border-t border-slate-200">
              <Text className="text-xs font-bold text-slate-600">Total Tagihan:</Text>
              <Text className="text-lg font-black text-emerald-700">
                Rp {activeTrx.total ? activeTrx.total.toLocaleString('id-ID') : '0'}
              </Text>
            </View>
          </View>

          {/* Items Summary */}
          <View className="w-full space-y-1">
            <Text className="text-[11px] font-bold text-slate-500">Rincian Obat:</Text>
            {activeTrx.items?.map((item, idx) => (
              <View key={idx} className="flex-row justify-between text-xs py-0.5">
                <Text className="text-slate-700 font-medium flex-1 pr-2" numberOfLines={1}>
                  {item.qty}x {item.product_name}
                </Text>
                <Text className="text-slate-900 font-bold">
                  Rp {item.subtotal ? item.subtotal.toLocaleString('id-ID') : '0'}
                </Text>
              </View>
            ))}
          </View>

          <View className="flex-row items-center space-x-2 pt-2">
            <ActivityIndicator size="small" color="#10b981" />
            <Text className="text-xs text-slate-500 font-medium">
              Menunggu pembayaran selesai...
            </Text>
          </View>
        </View>
      ) : (
        <View className="bg-slate-800 rounded-3xl p-8 items-center border border-slate-700 shadow-lg my-auto">
          <View className="w-16 h-16 rounded-2xl bg-slate-700 items-center justify-center mb-3">
            <Text className="text-2xl">📱</Text>
          </View>
          <Text className="text-base font-bold text-white text-center">
            Tidak Ada Transaksi QRIS Aktif
          </Text>
          <Text className="text-xs text-slate-400 text-center mt-1 leading-relaxed">
            Saat kasir memilih pembayaran QRIS di aplikasi desktop, kode QR otomatis muncul di layar HP ini untuk di-scan oleh pembeli.
          </Text>

          <TouchableOpacity
            onPress={fetchQris}
            className="mt-6 bg-slate-700 active:bg-slate-600 px-5 py-2.5 rounded-xl flex-row items-center space-x-2"
          >
            <Text className="text-xs font-bold text-slate-200">Periksa Ulang POS</Text>
          </TouchableOpacity>
        </View>
      )}

      <Text className="text-center text-[10px] text-slate-500 mt-6 pb-6">
        Sinkronisasi otomatis tiap 2.5 detik
      </Text>
    </ScrollView>
  );
}

