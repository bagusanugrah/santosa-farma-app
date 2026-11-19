import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/store_provider.dart';
import '../providers/web_orders_provider.dart';

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

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF047857)),
        label: 'Kasir',
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
          child: const Icon(Icons.shopping_bag, color: Color(0xFF047857)),
        ),
        label: 'Pesanan',
      ),
      const NavigationDestination(
        icon: Icon(Icons.medication_outlined),
        selectedIcon: Icon(Icons.medication, color: Color(0xFF047857)),
        label: 'Obat',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF047857)),
        label: 'Laporan',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings, color: Color(0xFF047857)),
        label: 'Setelan',
      ),
    ];

    final railDestinations = [
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
        icon: Icon(Icons.medication_outlined),
        selectedIcon: Icon(Icons.medication),
        label: Text('Kelola Obat'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: Text('Laporan'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Pengaturan'),
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
              color: storeProvider.isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: storeProvider.isOpen ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront,
                  size: 16,
                  color: storeProvider.isOpen ? const Color(0xFF059669) : Colors.red[700],
                ),
                const SizedBox(width: 6),
                Text(
                  storeProvider.isOpen ? 'BUKA' : 'TUTUP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: storeProvider.isOpen ? const Color(0xFF047857) : Colors.red[800],
                  ),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: storeProvider.isOpen,
                    onChanged: (val) => storeProvider.toggleStoreOpen(val),
                    activeColor: const Color(0xFF059669),
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
                  !storeProvider.isMidtransValid
                      ? 'WEB: KUNCI'
                      : (storeProvider.onlineOrdersEnabled ? 'WEB: AKTIF' : 'WEB: NONAKTIF'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: !storeProvider.isMidtransValid
                        ? Colors.red[700]
                        : (storeProvider.onlineOrdersEnabled ? const Color(0xFF1D4ED8) : const Color(0xFF334155)),
                  ),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: storeProvider.onlineOrdersEnabled,
                    onChanged: storeProvider.isMidtransValid
                        ? (val) => storeProvider.toggleOnlineOrders(val)
                        : (val) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pemesanan web terkunci: Kredensial Midtrans belum valid di Pengaturan Toko.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                    activeColor: const Color(0xFF2563EB),
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
                        style: TextStyle(fontSize: 12, color: sp.isOpen ? const Color(0xFF047857) : Colors.red),
                      ),
                      secondary: Icon(
                        Icons.storefront,
                        color: sp.isOpen ? const Color(0xFF059669) : Colors.red,
                      ),
                      activeColor: const Color(0xFF059669),
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: sp.onlineOrdersEnabled,
                      onChanged: sp.isMidtransValid
                          ? (val) => sp.toggleOnlineOrders(val)
                          : (val) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pemesanan web terkunci: Kredensial Midtrans belum valid di Pengaturan Toko.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                      title: const Text('Pemesanan Web Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        !sp.isMidtransValid
                            ? 'Terkunci (Kredensial Midtrans belum valid di Pengaturan Toko)'
                            : (sp.onlineOrdersEnabled ? 'Pelanggan web BISA memesan obat' : 'Pemesanan online sedang dinonaktifkan'),
                        style: TextStyle(
                          fontSize: 12,
                          color: !sp.isMidtransValid
                              ? Colors.red[700]
                              : (sp.onlineOrdersEnabled ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                        ),
                      ),
                      secondary: Icon(
                        Icons.language,
                        color: !sp.isMidtransValid ? Colors.red[400] : (sp.onlineOrdersEnabled ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                      ),
                      activeColor: const Color(0xFF2563EB),
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
          color: storeProvider.isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: storeProvider.isOpen ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront,
              size: 15,
              color: storeProvider.isOpen ? const Color(0xFF059669) : Colors.red[700],
            ),
            const SizedBox(width: 4),
            Text(
              storeProvider.isOpen ? 'BUKA' : 'TUTUP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: storeProvider.isOpen ? const Color(0xFF047857) : Colors.red[800],
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_pharmacy, color: Color(0xFF059669), size: 22),
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
                    const Text(
                      'Apotek Santosa Farma — Mode Tablet POS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            isWideTablet ? headerToggles : mobileStatusPill,
            if (actions != null) ...actions!,
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Keluar (${authProvider.currentUser?.name ?? "Kasir"})',
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
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        actions: [
          mobileStatusPill,
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
