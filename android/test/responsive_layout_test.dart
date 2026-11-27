import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:apotek_santosa_farma_pos/models/product.dart';
import 'package:apotek_santosa_farma_pos/models/store_setting.dart';
import 'package:apotek_santosa_farma_pos/models/transaction.dart';
import 'package:apotek_santosa_farma_pos/models/transaction_item.dart';
import 'package:apotek_santosa_farma_pos/providers/auth_provider.dart';
import 'package:apotek_santosa_farma_pos/providers/store_provider.dart';
import 'package:apotek_santosa_farma_pos/providers/web_orders_provider.dart';
import 'package:apotek_santosa_farma_pos/screens/login_screen.dart';
import 'package:apotek_santosa_farma_pos/widgets/adaptive_scaffold.dart';
import 'package:apotek_santosa_farma_pos/widgets/product_card.dart';
import 'package:apotek_santosa_farma_pos/widgets/quick_cash_buttons.dart';
import 'package:apotek_santosa_farma_pos/widgets/receipt_dialog.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        id: 1,
        name: 'Kasir Santosa',
        username: 'kasir',
        role: 'admin_kasir',
      );

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  Future<bool> login(String username, String password) async => true;

  @override
  Future<void> logout() async {}
}

class _FakeWebOrdersProvider extends ChangeNotifier implements WebOrdersProvider {
  @override
  bool get isLoading => false;

  @override
  int get newOrdersCount => 0;

  @override
  List<TransactionModel> get orders => const [];

  @override
  int get pendingPickupCount => 2;

  @override
  void resetNewOrdersCount() {}

  @override
  Future<void> loadOrders() async {}

  @override
  Future<TransactionModel?> verifyPickup(String codeOrInvoice) async => null;
}

class _FakeStoreProvider extends ChangeNotifier implements StoreProvider {
  final StoreSetting _setting = StoreSetting(
    id: 1,
    isOpen: true,
    onlineOrdersEnabled: true,
    storeAddress: 'Jl. Kesehatan No. 10, Bandung',
    storePhone: '08123456789',
  );

  @override
  bool get isLoading => false;

  @override
  bool get isMidtransValid => false;

  @override
  bool get isOnlineActive => true;

  @override
  bool get isOpen => true;

  @override
  bool get isValidatingMidtrans => false;

  @override
  bool get onlineOrdersEnabled => true;

  @override
  StoreSetting get setting => _setting;

  @override
  Future<void> loadStatus() async {}

  @override
  Future<bool> testMidtransConnection({
    required String clientKey,
    required String serverKey,
    required bool isProduction,
  }) async =>
      true;

  @override
  Future<void> updateStoreProfile({
    required String storeAddress,
    required String storePhone,
  }) async {}

  @override
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
  }) async {}

  @override
  Future<bool> toggleOnlineOrders(bool value) async => true;

  @override
  Future<void> toggleStoreOpen(bool value) async {}
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('AdaptiveScaffold switches cleanly between phone and tablet breakpoints', (tester) async {
    final testSizes = <Size>[
      const Size(320, 568), // Small phone
      const Size(384, 854), // Standard smartphone (Tecno Spark class)
      const Size(720, 360), // Landscape phone
      const Size(800, 1280), // Tablet portrait
      const Size(1280, 800), // Wide tablet landscape
    ];

    for (final size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuthProvider()),
            ChangeNotifierProvider<WebOrdersProvider>.value(value: _FakeWebOrdersProvider()),
          ],
          child: const MaterialApp(
            home: AdaptiveScaffold(
              currentIndex: 0,
              onNavigationChanged: _noop,
              title: 'Kasir POS Apotek',
              body: SizedBox.expand(child: Center(child: Text('Konten Utama'))),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Unexpected layout error at size $size');

      if (size.width >= 600) {
        expect(find.byType(NavigationRail), findsOneWidget, reason: 'Expected NavigationRail at $size');
        expect(find.byType(NavigationBar), findsNothing, reason: 'Did not expect NavigationBar at $size');
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, size.width >= 1100);
      } else {
        expect(find.byType(NavigationBar), findsOneWidget, reason: 'Expected NavigationBar at $size');
        expect(find.byType(NavigationRail), findsNothing, reason: 'Did not expect NavigationRail at $size');
      }
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('ProductCard, QuickCashButtons, LoginScreen & ReceiptDialog fit without overflow on small & tablet screens', (tester) async {
    final sampleProduct = Product(
      id: 1,
      name: 'Amoxicillin Trihydrate 500mg Strip Isi 10 Kaplet',
      category: 'Daya Tahan Tubuh',
      price: 125000,
      stock: 48,
    );

    final sampleTrx = TransactionModel(
      id: 1,
      invoiceNo: 'INV-20261127-9999',
      total: 125000,
      paymentMethod: 'tunai',
      amountPaid: 150000,
      changeAmount: 25000,
      status: 'selesai',
      channel: 'toko',
      createdAt: DateTime(2026, 11, 27, 21, 0),
      items: [
        TransactionItem(
          id: 1,
          transactionId: 1,
          productId: 1,
          productName: sampleProduct.name,
          qty: 1,
          price: 125000,
          subtotal: 125000,
        ),
      ],
    );

    for (final size in [const Size(320, 568), const Size(1280, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      // 1. ProductCard inside narrow grid slot + QuickCashButtons
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 142,
                    height: 248,
                    child: ProductCard(
                      product: sampleProduct,
                      inCartQty: 2,
                      onAddToCart: () {},
                    ),
                  ),
                  QuickCashButtons(total: 125000, onAmountSelected: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'ProductCard/QuickCash error at $size');

      // 2. ReceiptDialog
      await tester.pumpWidget(
        ChangeNotifierProvider<StoreProvider>.value(
          value: _FakeStoreProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: ReceiptDialog(transaction: sampleTrx),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'ReceiptDialog error at $size');

      // 3. LoginScreen
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: _FakeAuthProvider(),
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'LoginScreen error at $size');
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

void _noop(int _) {}
