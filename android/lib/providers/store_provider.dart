import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_setting.dart';
import '../services/supabase_service.dart';

class StoreProvider extends ChangeNotifier {
  StoreSetting _setting = StoreSetting(id: 1, isOpen: true, onlineOrdersEnabled: false);
  bool _isLoading = true;
  bool _isMidtransValid = false;
  bool _isValidatingMidtrans = false;
  RealtimeChannel? _subscription;

  StoreSetting get setting => _setting;
  bool get isOpen => _setting.isOpen;
  bool get onlineOrdersEnabled => _setting.onlineOrdersEnabled;
  bool get isOnlineActive => _setting.isOpen && _setting.onlineOrdersEnabled;
  bool get isLoading => _isLoading;
  bool get isMidtransValid => _isMidtransValid;
  bool get isValidatingMidtrans => _isValidatingMidtrans;

  StoreProvider() {
    loadStatus();
    _subscribeRealtime();
  }

  Future<void> loadStatus() async {
    _setting = await SupabaseService.instance.getStoreSetting();
    await _validateAndSyncMidtrans();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _validateAndSyncMidtrans() async {
    if (!_setting.hasMidtransConfig) {
      _isMidtransValid = false;
      return;
    }

    _isValidatingMidtrans = true;
    final valid = await SupabaseService.instance.verifyMidtransCredentials(
      clientKey: _setting.midtransClientKey,
      serverKey: _setting.midtransServerKey,
      isProduction: _setting.midtransIsProduction,
    );
    _isMidtransValid = valid;
    _isValidatingMidtrans = false;
  }

  void _subscribeRealtime() {
    final client = SupabaseService.instance.client;
    _subscription = client
        .channel('public:store_settings_pos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'store_settings',
          callback: (payload) async {
            try {
              if (payload.newRecord.isNotEmpty) {
                _setting = StoreSetting.fromMap(payload.newRecord);
                await _validateAndSyncMidtrans();
                notifyListeners();
              }
            } catch (e) {
              debugPrint('Realtime store_settings parse error: $e');
            }
          },
        )
        .subscribe();
  }

  Future<void> toggleStoreOpen(bool val) async {
    _setting = _setting.copyWith(isOpen: val);
    notifyListeners();
    await SupabaseService.instance.updateStoreStatus(
      isOpen: val,
      onlineOrdersEnabled: _setting.onlineOrdersEnabled,
    );
  }

  /// Toggle online orders (Customer can order via web, with either Bayar di Apotek or Midtrans)
  Future<bool> toggleOnlineOrders(bool val) async {
    _setting = _setting.copyWith(onlineOrdersEnabled: val);
    notifyListeners();
    await SupabaseService.instance.updateStoreStatus(
      isOpen: _setting.isOpen,
      onlineOrdersEnabled: val,
    );
    return true;
  }

  /// Test Midtrans credentials interactively from UI
  Future<bool> testMidtransConnection({
    required String clientKey,
    required String serverKey,
    required bool isProduction,
  }) async {
    return await SupabaseService.instance.verifyMidtransCredentials(
      clientKey: clientKey,
      serverKey: serverKey,
      isProduction: isProduction,
    );
  }

  Future<void> updateIntegrationSettings({
    required String fonnteToken,
    required String fonnteUrl,
    required String mailHost,
    required int mailPort,
    required String mailUsername,
    required String mailPassword,
    required String mailFromName,
    required String midtransClientKey,
    required String midtransServerKey,
    required bool midtransIsProduction,
  }) async {
    await SupabaseService.instance.updateIntegrationSettings(
      fonnteToken: fonnteToken,
      fonnteUrl: fonnteUrl,
      mailHost: mailHost,
      mailPort: mailPort,
      mailUsername: mailUsername,
      mailPassword: mailPassword,
      mailFromName: mailFromName,
      midtransClientKey: midtransClientKey,
      midtransServerKey: midtransServerKey,
      midtransIsProduction: midtransIsProduction,
    );
    await loadStatus();
  }

  @override
  void dispose() {
    if (_subscription != null) {
      SupabaseService.instance.client.removeChannel(_subscription!);
    }
    super.dispose();
  }
}
