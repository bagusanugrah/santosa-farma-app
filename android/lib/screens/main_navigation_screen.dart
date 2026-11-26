import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/adaptive_scaffold.dart';
import 'cashier_transactions_screen.dart';
import 'login_screen.dart';
import 'pos_screen.dart';
import 'web_orders_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool? _lastIsSuperAdmin;

  // Layar & Judul untuk Super Admin (Manajemen Apotek)
  final List<String> _adminTitles = const [
    'Katalog & Kelola Obat',
    'Laporan Penjualan (Read-Only)',
    'Pengaturan Apotek & Sistem',
  ];

  final List<Widget> _adminScreens = const [
    ProductsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  // Layar & Judul untuk Kasir Toko (Pelayanan Transaksi)
  final List<String> _kasirTitles = const [
    'Kasir POS Apotek',
    'Transaksi Kasir (Toko)',
    'Pesanan Web Pelanggan',
    'Pengaturan & Akun Kasir',
  ];

  final List<Widget> _kasirScreens = const [
    PosScreen(),
    CashierTransactionsScreen(),
    WebOrdersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated || auth.currentUser == null) {
      return const LoginScreen();
    }
    final isSuperAdmin = auth.currentUser?.isSuperAdmin == true;

    // Reset index jika berganti role user saat logout/login
    if (_lastIsSuperAdmin != null && _lastIsSuperAdmin != isSuperAdmin) {
      _currentIndex = 0;
    }
    _lastIsSuperAdmin = isSuperAdmin;

    final screens = isSuperAdmin ? _adminScreens : _kasirScreens;
    final titles = isSuperAdmin ? _adminTitles : _kasirTitles;

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return AdaptiveScaffold(
      currentIndex: _currentIndex,
      onNavigationChanged: (index) {
        setState(() => _currentIndex = index);
      },
      title: titles[_currentIndex],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
