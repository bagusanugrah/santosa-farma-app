import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/store_provider.dart';
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
    final isWideTablet = screenWidth >= 980;
    final storeProvider = context.watch<StoreProvider>();
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

    final headerToggles = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Store Open/Close Toggle
        Tooltip(
          message: 'Buka atau Tutup Apotek',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: storeProvider.isOpen ? const Color(0xFFECFEFF) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: storeProvider.isOpen ? const Color(0xFFA5F3FC) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront,
                  size: 16,
                  color: storeProvider.isOpen ? const Color(0xFF0891B2) : Colors.red[700],
                ),
                const SizedBox(width: 6),
                Text(
                  storeProvider.isOpen ? 'BUKA' : 'TUTUP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: storeProvider.isOpen ? const Color(0xFF0E7490) : Colors.red[800],
                  ),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: storeProvider.isOpen,
                    onChanged: (val) => storeProvider.toggleStoreOpen(val),
                    activeColor: const Color(0xFF0891B2),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Web Orders Online Toggle
        Tooltip(
          message: 'Matikan / Hidupkan Pemesanan di Web Pelanggan',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: storeProvider.onlineOrdersEnabled ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: storeProvider.onlineOrdersEnabled ? const Color(0xFFBFDBFE) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.language,
                  size: 16,
                  color: storeProvider.onlineOrdersEnabled ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  storeProvider.onlineOrdersEnabled
                      ? (storeProvider.isMidtransValid ? 'WEB: AKTIF' : 'WEB: BAYAR APOTEK')
                      : 'WEB: NONAKTIF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: storeProvider.onlineOrdersEnabled
                        ? (storeProvider.isMidtransValid ? const Color(0xFF1D4ED8) : const Color(0xFF0891B2))
                        : const Color(0xFF334155),
                  ),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: storeProvider.onlineOrdersEnabled,
                    onChanged: (val) => storeProvider.toggleOnlineOrders(val),
                    activeColor: const Color(0xFF0891B2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    void showStoreStatusSheet() {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Consumer<StoreProvider>(
          builder: (ctx, sp, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kontrol Operasional Apotek',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: sp.isOpen,
                      onChanged: (val) => sp.toggleStoreOpen(val),
                      title: const Text('Status Buka Apotek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        sp.isOpen ? 'Apotek sedang BUKA melayani pembeli' : 'Apotek sedang TUTUP',
                        style: TextStyle(fontSize: 12, color: sp.isOpen ? const Color(0xFF0E7490) : Colors.red),
                      ),
                      secondary: Icon(
                        Icons.storefront,
                        color: sp.isOpen ? const Color(0xFF0891B2) : Colors.red,
                      ),
                      activeColor: const Color(0xFF0891B2),
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: sp.onlineOrdersEnabled,
                      onChanged: (val) => sp.toggleOnlineOrders(val),
                      title: const Text('Pemesanan Web Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        sp.onlineOrdersEnabled
                            ? (sp.isMidtransValid
                                ? 'Pelanggan dapat memesan (Midtrans Online & Bayar di Apotek)'
                                : 'Pelanggan dapat memesan (Metode: Bayar di Apotek)')
                            : 'Pemesanan online sedang dinonaktifkan sementara',
                        style: TextStyle(
                          fontSize: 12,
                          color: sp.onlineOrdersEnabled
                              ? (sp.isMidtransValid ? const Color(0xFF2563EB) : const Color(0xFF0891B2))
                              : const Color(0xFF64748B),
                        ),
                      ),
                      secondary: Icon(
                        Icons.language,
                        color: sp.onlineOrdersEnabled ? const Color(0xFF0891B2) : const Color(0xFF64748B),
                      ),
                      activeColor: const Color(0xFF0891B2),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final mobileStatusPill = InkWell(
      onTap: showStoreStatusSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: storeProvider.isOpen ? const Color(0xFFECFEFF) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: storeProvider.isOpen ? const Color(0xFFA5F3FC) : const Color(0xFFFECACA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront,
              size: 15,
              color: storeProvider.isOpen ? const Color(0xFF0891B2) : Colors.red[700],
            ),
            const SizedBox(width: 4),
            Text(
              storeProvider.isOpen ? 'BUKA' : 'TUTUP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: storeProvider.isOpen ? const Color(0xFF0E7490) : Colors.red[800],
              ),
            ),
            const SizedBox(width: 6),
            Container(width: 1, height: 12, color: const Color(0xFFCBD5E1)),
            const SizedBox(width: 6),
            Icon(
              Icons.language,
              size: 14,
              color: storeProvider.onlineOrdersEnabled ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );

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
            if (isSuperAdmin) ...[
              isWideTablet ? headerToggles : mobileStatusPill,
            ] else ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: storeProvider.isOpen ? const Color(0xFFECFEFF) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: storeProvider.isOpen ? const Color(0xFFA5F3FC) : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      storeProvider.isOpen ? Icons.storefront : Icons.storefront_outlined,
                      size: 13,
                      color: storeProvider.isOpen ? const Color(0xFF0891B2) : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      storeProvider.isOpen ? 'Apotek Buka' : 'Apotek Tutup',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: storeProvider.isOpen ? const Color(0xFF0E7490) : Colors.red,
                      ),
                    ),
                  ],
                ),
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
          if (isSuperAdmin) ...[
            mobileStatusPill,
          ] else ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: storeProvider.isOpen ? const Color(0xFFECFEFF) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: storeProvider.isOpen ? const Color(0xFFA5F3FC) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    storeProvider.isOpen ? Icons.storefront : Icons.storefront_outlined,
                    size: 12,
                    color: storeProvider.isOpen ? const Color(0xFF0891B2) : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    storeProvider.isOpen ? 'Buka' : 'Tutup',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: storeProvider.isOpen ? const Color(0xFF0E7490) : Colors.red,
                    ),
                  ),
                ],
              ),
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
