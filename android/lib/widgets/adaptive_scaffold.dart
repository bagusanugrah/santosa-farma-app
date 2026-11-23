import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/web_orders_provider.dart';
import '../screens/qr_scanner_screen.dart';

class AdaptiveScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigationChanged;
  final Widget body;
  final String title;
  final List<Widget>? actions;

  const AdaptiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onNavigationChanged,
    required this.body,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 800;
    final webOrdersProvider = context.watch<WebOrdersProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isSuperAdmin = authProvider.currentUser?.isSuperAdmin == true;

    final destinations = isSuperAdmin
        ? [
            const NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication, color: Color(0xFF0E7490)),
              label: 'Kelola Obat',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF0E7490)),
              label: 'Laporan',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: Color(0xFF0E7490)),
              label: 'Setelan',
            ),
          ]
        : [
            const NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF0E7490)),
              label: 'Kasir POS',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF0E7490)),
              label: 'Transaksi Kasir',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: webOrdersProvider.pendingPickupCount > 0,
                label: Text('${webOrdersProvider.pendingPickupCount}'),
                backgroundColor: Colors.amber[700],
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: webOrdersProvider.pendingPickupCount > 0,
                label: Text('${webOrdersProvider.pendingPickupCount}'),
                backgroundColor: Colors.amber[700],
                child: const Icon(Icons.shopping_bag, color: Color(0xFF0E7490)),
              ),
              label: 'Pesanan Web',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Color(0xFF0E7490)),
              label: 'Akun Kasir',
            ),
          ];

    final railDestinations = isSuperAdmin
        ? [
            const NavigationRailDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: Text('Kelola Obat'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: Text('Laporan Penjualan'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: Text('Pengaturan Apotek'),
            ),
          ]
        : [
            const NavigationRailDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale),
              label: Text('Kasir POS'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: Text('Transaksi Kasir'),
            ),
            NavigationRailDestination(
              icon: Badge(
                isLabelVisible: webOrdersProvider.pendingPickupCount > 0,
                label: Text('${webOrdersProvider.pendingPickupCount}'),
                backgroundColor: Colors.amber[700],
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: webOrdersProvider.pendingPickupCount > 0,
                label: Text('${webOrdersProvider.pendingPickupCount}'),
                backgroundColor: Colors.amber[700],
                child: const Icon(Icons.shopping_bag),
              ),
              label: const Text('Pesanan Web'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: Text('Akun Kasir'),
            ),
          ];

    if (isTablet) {
      // Tablet / Landscape Split Layout
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    Text(
                      isSuperAdmin
                          ? 'Apotek Santosa Farma — Manajemen Super Admin'
                          : 'Apotek Santosa Farma — Pelayanan Kasir POS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Role Badge (ADMIN vs KASIR)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSuperAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFECFEFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSuperAdmin ? const Color(0xFF93C5FD) : const Color(0xFFA5F3FC),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuperAdmin ? Icons.admin_panel_settings : Icons.badge,
                    size: 14,
                    color: isSuperAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF0E7490),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSuperAdmin ? 'ADMIN' : 'KASIR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isSuperAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF0E7490),
                    ),
                  ),
                ],
              ),
            ),
            if (!isSuperAdmin) ...[
              IconButton(
                tooltip: 'Scan QR Pesanan Pelanggan',
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0891B2)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                },
              ),
            ],
            if (actions != null) ...actions!,
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Keluar (${authProvider.currentUser?.name ?? (isSuperAdmin ? "Admin" : "Kasir")})',
              icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
              onPressed: () => authProvider.logout(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onNavigationChanged,
              labelType: NavigationRailLabelType.all,
              destinations: railDestinations,
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Smartphone / Portrait Layout
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSuperAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFECFEFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSuperAdmin ? const Color(0xFF93C5FD) : const Color(0xFFA5F3FC),
                ),
              ),
              child: Text(
                isSuperAdmin ? 'ADMIN' : 'KASIR',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: isSuperAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF0E7490),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!isSuperAdmin) ...[
            IconButton(
              tooltip: 'Scan QR Pesanan',
              icon: const Icon(Icons.qr_code_scanner, size: 20, color: Color(0xFF0891B2)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                );
              },
            ),
          ],
          if (actions != null) ...actions!,
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Keluar',
            onPressed: () => authProvider.logout(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: currentIndex,
        onDestinationSelected: onNavigationChanged,
        destinations: destinations,
      ),
    );
  }
}
