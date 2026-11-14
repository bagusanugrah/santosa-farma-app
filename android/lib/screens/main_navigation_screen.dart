import 'package:flutter/material.dart';
import '../widgets/adaptive_scaffold.dart';
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

  final List<String> _titles = [
    'Kasir POS',
    'Pesanan Web Pelanggan',
    'Katalog & Stok Obat',
    'Laporan Penjualan',
    'Pengaturan Kasir & Apotek',
  ];

  final List<Widget> _screens = const [
    PosScreen(),
    WebOrdersScreen(),
    ProductsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      currentIndex: _currentIndex,
      onNavigationChanged: (index) {
        setState(() => _currentIndex = index);
      },
      title: _titles[_currentIndex],
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
