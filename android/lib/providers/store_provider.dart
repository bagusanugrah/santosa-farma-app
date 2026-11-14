import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_setting.dart';
import '../services/supabase_service.dart';

class StoreProvider extends ChangeNotifier {
  StoreSetting _setting = StoreSetting(id: 1, isOpen: true, onlineOrdersEnabled: false);
  bool _isLoading = true;
  RealtimeChannel? _subscription;

  StoreSetting get setting => _setting;
  bool get isOpen => _setting.isOpen;
  bool get onlineOrdersEnabled => _setting.onlineOrdersEnabled;
  bool get isOnlineActive => _setting.isOnlineActive;
  bool get isLoading => _isLoading;

  StoreProvider() {
    loadStatus();
    _subscribeRealtime();
  }

  Future<void> loadStatus() async {
    _setting = await SupabaseService.instance.getStoreSetting();
    _isLoading = false;
    notifyListeners();
  }

  void _subscribeRealtime() {
    final client = SupabaseService.instance.client;
    _subscription = client
        .channel('public:store_settings_pos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'store_settings',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              _setting = StoreSetting.fromMap(payload.newRecord);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  Future<void> toggleStoreOpen(bool val) async {
    _setting = StoreSetting(
      id: _setting.id,
      isOpen: val,
      onlineOrdersEnabled: _setting.onlineOrdersEnabled,
    );
    notifyListeners();
    await SupabaseService.instance.updateStoreStatus(
      isOpen: val,
      onlineOrdersEnabled: _setting.onlineOrdersEnabled,
    );
  }

  Future<void> toggleOnlineOrders(bool val) async {
    _setting = StoreSetting(
      id: _setting.id,
      isOpen: _setting.isOpen,
      onlineOrdersEnabled: val,
    );
    notifyListeners();
    await SupabaseService.instance.updateStoreStatus(
      isOpen: _setting.isOpen,
      onlineOrdersEnabled: val,
    );
  }

  @override
  void dispose() {
    if (_subscription != null) {
      SupabaseService.instance.client.removeChannel(_subscription!);
    }
    super.dispose();
  }
}
