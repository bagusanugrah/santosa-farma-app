import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  ActivityIndicator,
  Modal,
  ScrollView,
  TextInput,
  Alert,
} from 'react-native';
import { Camera, CameraView, useCameraPermissions } from 'expo-camera';
import { getOrderByQr, confirmOrderPickup } from '../services/api';

export default function ScanPickupScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [loading, setLoading] = useState(false);
  const [manualToken, setManualToken] = useState('');
  const [orderDetails, setOrderDetails] = useState(null);
  const [modalVisible, setModalVisible] = useState(false);
  const [confirming, setConfirming] = useState(false);

  const handleBarCodeScanned = async ({ data }) => {
    if (scanned || loading) return;
    setScanned(true);
    await processQrToken(data);
  };

  const processQrToken = async (token) => {
    if (!token) return;
    setLoading(true);

    try {
      const res = await getOrderByQr(token.trim());
      setOrderDetails(res.data);
      setModalVisible(true);
    } catch (err) {
      Alert.alert(
        'QR Code Tidak Valid',
        err.message || 'Pesanan dengan kode QR ini tidak ditemukan.',
        [{ text: 'OK', onPress: () => setScanned(false) }]
      );
    } finally {
      setLoading(false);
    }
  };

  const handleManualSubmit = () => {
    if (!manualToken.trim()) return;
    processQrToken(manualToken);
  };

  const handleConfirmPickup = async () => {
    if (!orderDetails || !orderDetails.qr_token) return;
    setConfirming(true);

    try {
      const res = await confirmOrderPickup(orderDetails.qr_token);
      Alert.alert(
        'Berhasil Diambil!',
        `Pesanan ${orderDetails.invoice_no} telah berhasil dikonfirmasi dan diserahkan kepada pelanggan.`,
        [
          {
            text: 'OK',
            onPress: () => {
              setModalVisible(false);
              setOrderDetails(null);
              setScanned(false);
              setManualToken('');
            },
          },
        ]
      );
    } catch (err) {
      Alert.alert('Gagal Konfirmasi', err.message || 'Terjadi kesalahan.');
    } finally {
      setConfirming(false);
    }
  };

  return (
    <View className="flex-1 bg-slate-900">
      {/* Header */}
      <View className="p-4 items-center border-b border-slate-800">
        <Text className="text-lg font-black text-white">Scan QR Pengambilan Online</Text>
        <Text className="text-xs text-slate-400 mt-0.5">
          Arahkan kamera ke QR Code di HP Pelanggan
        </Text>
      </View>

      {/* Camera Scanner View */}
      <View className="flex-1 overflow-hidden relative justify-center items-center bg-black">
        {permission?.granted ? (
          <CameraView
            style={{ width: '100%', height: '100%' }}
            barcodeScannerSettings={{
              barcodeTypes: ['qr'],
            }}
            onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
          >
            {/* Scanner Overlay UI */}
            <View className="flex-1 justify-center items-center">
              <View className="w-64 h-64 border-2 border-emerald-400 rounded-3xl bg-transparent relative justify-center items-center shadow-lg">
                <View className="w-60 h-0.5 bg-emerald-400/80 animate-pulse" />
              </View>
              <Text className="text-xs text-white bg-black/60 px-4 py-1.5 rounded-full font-bold mt-4">
                Posisikan QR Code di dalam kotak
              </Text>
            </View>
          </CameraView>
        ) : (
          <View className="p-6 items-center justify-center space-y-4">
            <Text className="text-sm font-bold text-white text-center">
              Akses kamera diperlukan untuk memindai QR Code
            </Text>
            <TouchableOpacity
              onPress={requestPermission}
              className="bg-emerald-500 px-5 py-2.5 rounded-xl"
            >
              <Text className="text-slate-950 font-bold text-xs">Izinkan Akses Kamera</Text>
            </TouchableOpacity>
          </View>
        )}

        {loading && (
          <View className="absolute inset-0 bg-black/70 items-center justify-center">
            <ActivityIndicator size="large" color="#10b981" />
            <Text className="text-white text-xs font-bold mt-3">
              Memvalidasi Pesanan...
            </Text>
          </View>
        )}
      </View>

      {/* Manual Input Fallback */}
      <View className="p-4 bg-slate-800 border-t border-slate-700 space-y-2">
        <Text className="text-[11px] font-bold text-slate-400">
          Atau Masukkan Kode Token Pengambilan / Invoice:
        </Text>
        <View className="flex-row space-x-2">
          <TextInput
            value={manualToken}
            onChangeText={setManualToken}
            placeholder="PKP-xxxxx atau INV-ONL-xxx"
            placeholderTextColor="#64748b"
            autoCapitalize="characters"
            className="flex-1 bg-slate-900 border border-slate-700 text-white rounded-xl px-3 py-2 text-xs font-mono"
          />
          <TouchableOpacity
            onPress={handleManualSubmit}
            disabled={!manualToken.trim() || loading}
            className="bg-emerald-500 active:bg-emerald-600 disabled:opacity-40 px-4 rounded-xl items-center justify-center"
          >
            <Text className="text-slate-950 font-black text-xs">Cari</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Order Details & Pickup Confirmation Modal */}
      <Modal visible={modalVisible} animationType="slide" transparent>
        <View className="flex-1 bg-black/70 justify-end">
          <View className="bg-white rounded-t-3xl p-6 max-h-[85%] space-y-4">
            <View className="flex-row justify-between items-center pb-3 border-b border-slate-100">
              <View>
                <Text className="text-base font-black text-slate-900">
                  {orderDetails?.invoice_no}
                </Text>
                <Text className="text-xs text-slate-500">
                  Pemesan: {orderDetails?.customer?.name || 'Customer Online'}
                </Text>
              </View>
              <View
                className={`px-3 py-1 rounded-full ${
                  orderDetails?.status === 'paid'
                    ? 'bg-emerald-100'
                    : orderDetails?.status === 'diambil'
                    ? 'bg-blue-100'
                    : 'bg-amber-100'
                }`}
              >
                <Text
                  className={`text-xs font-bold uppercase ${
                    orderDetails?.status === 'paid'
                      ? 'text-emerald-800'
                      : orderDetails?.status === 'diambil'
                      ? 'text-blue-800'
                      : 'text-amber-800'
                  }`}
                >
                  {orderDetails?.status === 'paid' ? 'Siap Diambil' : orderDetails?.status}
                </Text>
              </View>
            </View>

            <ScrollView className="max-h-56 space-y-2">
              <Text className="text-xs font-bold text-slate-400 mb-1">DAFTAR OBAT:</Text>
              {orderDetails?.items?.map((item, idx) => (
                <View key={idx} className="flex-row justify-between py-1 border-b border-slate-100">
                  <Text className="text-xs font-bold text-slate-800 flex-1 pr-2">
                    {item.qty}x {item.product_name}
                  </Text>
                  <Text className="text-xs font-extrabold text-slate-900">
                    Rp {item.subtotal ? item.subtotal.toLocaleString('id-ID') : '0'}
                  </Text>
                </View>
              ))}
            </ScrollView>

            <View className="bg-slate-50 p-3 rounded-2xl border border-slate-100 flex-row justify-between items-center">
              <Text className="text-xs font-bold text-slate-600">Total Pembayaran:</Text>
              <Text className="text-lg font-black text-emerald-700">
                Rp {orderDetails?.total ? orderDetails.total.toLocaleString('id-ID') : '0'}
              </Text>
            </View>

            {orderDetails?.status === 'diambil' ? (
              <View className="bg-blue-50 p-3 rounded-xl border border-blue-200">
                <Text className="text-xs text-blue-800 font-bold text-center">
                  Pesanan ini sudah diserahkan kepada pelanggan sebelumnya.
                </Text>
              </View>
            ) : orderDetails?.status === 'paid' ? (
              <TouchableOpacity
                onPress={handleConfirmPickup}
                disabled={confirming}
                className="w-full py-4 bg-emerald-500 active:bg-emerald-600 rounded-2xl items-center justify-center shadow-lg shadow-emerald-500/20"
              >
                {confirming ? (
                  <ActivityIndicator color="#0f172a" />
                ) : (
                  <Text className="text-slate-950 font-black text-sm">
                    ✓ Konfirmasi Pesanan Diambil
                  </Text>
                )}
              </TouchableOpacity>
            ) : (
              <View className="bg-amber-50 p-3 rounded-xl border border-amber-200">
                <Text className="text-xs text-amber-800 font-bold text-center">
                  Pesanan belum dapat diambil (Status: {orderDetails?.status}).
                </Text>
              </View>
            )}

            <TouchableOpacity
              onPress={() => {
                setModalVisible(false);
                setScanned(false);
              }}
              className="py-2.5 bg-slate-100 active:bg-slate-200 rounded-xl items-center"
            >
              <Text className="text-xs font-bold text-slate-700">Tutup</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

