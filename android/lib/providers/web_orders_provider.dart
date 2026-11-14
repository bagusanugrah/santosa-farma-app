import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../services/audio_service.dart';
import '../services/supabase_service.dart';

class WebOrdersProvider extends ChangeNotifier {
  List<TransactionModel> _orders = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;
  int _newOrdersCount = 0;

  List<TransactionModel> get orders => _orders;
  bool get isLoading => _isLoading;
  int get newOrdersCount => _newOrdersCount;

  int get pendingPickupCount =>
      _orders.where((o) => o.status == 'paid').length;

  WebOrdersProvider() {
    loadOrders();
    _subscribeRealtime();
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      _orders = await SupabaseService.instance.getWebOrders();
    } catch (e) {
      // Load orders fallback
    }
    _isLoading = false;
    notifyListeners();
  }

  void resetNewOrdersCount() {
    _newOrdersCount = 0;
    notifyListeners();
  }

  void _subscribeRealtime() {
    final client = SupabaseService.instance.client;
    _subscription = client
        .channel('public:transactions_web_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) async {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty && newRecord['channel'] == 'online') {
              // Play audio chime for incoming online order or payment
              await AudioService.instance.playOrderChime();
              _newOrdersCount++;
              await loadOrders();
            }
          },
        )
        .subscribe();
  }

  Future<TransactionModel?> verifyPickup(String qrTokenOrInvoice) async {
    final updated = await SupabaseService.instance.verifyAndPickupOrder(qrTokenOrInvoice);
    if (updated != null) {
      await loadOrders();
    }
    return updated;
  }

  @override
  void dispose() {
    if (_subscription != null) {
      SupabaseService.instance.client.removeChannel(_subscription!);
    }
    super.dispose();
  }
}
