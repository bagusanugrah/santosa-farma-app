import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transaction.dart';
import '../providers/web_orders_provider.dart';
import '../widgets/process_web_order_dialog.dart';
import '../widgets/receipt_dialog.dart';
import 'qr_scanner_screen.dart';

class WebOrdersScreen extends StatefulWidget {
  const WebOrdersScreen({super.key});

  @override
  State<WebOrdersScreen> createState() => _WebOrdersScreenState();
}

class _WebOrdersScreenState extends State<WebOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filterOrders(List<TransactionModel> allOrders, int tabIndex) {
    switch (tabIndex) {
      case 1: // Bayar di Apotek
        return allOrders.where((o) => o.status == 'pending').toList();
      case 2: // Siap Diambil (Lunas)
        return allOrders.where((o) => o.status == 'paid').toList();
      case 3: // Sudah Diambil / Selesai
        return allOrders.where((o) => o.status == 'diambil' || o.status == 'selesai').toList();
      default:
        return allOrders;
    }
  }

  Widget _buildStatusBadge(TransactionModel order) {
    Color bg;
    Color text;
    String label;

    switch (order.status) {
      case 'paid':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'Siap Diambil di Toko (LUNAS)';
        break;
      case 'diambil':
      case 'selesai':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'Sudah Selesai';
        break;
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = order.isPayAtPharmacy ? 'Bayar di Kasir (Apotek)' : 'Menunggu Bayar Online';
        break;
      case 'dibatalkan':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        label = 'Dibatalkan';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        label = order.status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final webOrdersProvider = context.watch<WebOrdersProvider>();

    return Column(
      children: [
        // Top Action Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Pengambilan Obat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7490),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: 'Muat Ulang Pesanan',
                icon: const Icon(Icons.refresh, color: Color(0xFF0E7490)),
                onPressed: () => webOrdersProvider.loadOrders(),
              ),
            ],
          ),
        ),

        // Filter Tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF0E7490),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF0891B2),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              const Tab(text: 'Semua'),
              Tab(text: 'Bayar di Apotek (${webOrdersProvider.orders.where((o) => o.status == 'pending').length})'),
              Tab(text: 'Siap Diambil (${webOrdersProvider.pendingPickupCount})'),
              const Tab(text: 'Sudah Selesai'),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Orders List
        Expanded(
          child: webOrdersProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0891B2)))
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(4, (tabIndex) {
                    final filtered = _filterOrders(webOrdersProvider.orders, tabIndex);

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum ada transaksi di tab ini',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Pesanan online yang masuk melalui website akan otomatis tampil di sini',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () => webOrdersProvider.loadOrders(),
                      color: const Color(0xFF0891B2),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Order Header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order.invoiceNo,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                            ),
                                            Text(
                                              dateFormat.format(order.createdAt),
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusBadge(order),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  // Customer Details
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          order.customerName ?? 'Pelanggan Web',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                      if (order.customerPhone != null) ...[
                                        const SizedBox(width: 12),
                                        InkWell(
                                          onTap: () {
                                            final phone = order.customerPhone!.replaceAll(RegExp(r'[^0-9]'), '');
                                            launchUrl(Uri.parse('https://wa.me/$phone'));
                                          },
                                          child: Row(
                                            children: [
                                              const Icon(Icons.chat, size: 14, color: Color(0xFF16A34A)),
                                              const SizedBox(width: 4),
                                              Text(
                                                order.customerPhone!,
                                                style: const TextStyle(
                                                  color: Color(0xFF16A34A),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Items
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: order.items.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${item.qty}x ${item.productName}',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                currency.format(item.subtotal),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Total & Action Button (Wrap prevents overflow on narrow smartphones)
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 10,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Total Pesanan', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          Text(
                                            currency.format(order.total),
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0E7490)),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (order.status == 'pending')
                                            FilledButton.icon(
                                              icon: const Icon(Icons.point_of_sale, size: 16),
                                              label: const Text('Edit & Bayar di Kasir'),
                                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0891B2)),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (_) => ProcessWebOrderDialog(order: order),
                                                );
                                              },
                                            ),
                                          if (order.status == 'paid')
                                            FilledButton.icon(
                                              icon: const Icon(Icons.handshake, size: 16),
                                              label: const Text('Serah Terima Obat'),
                                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0891B2)),
                                              onPressed: () async {
                                                final updated = await webOrdersProvider.verifyPickup(order.invoiceNo);
                                                if (updated != null) {
                                                  if (!context.mounted) return;
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => ReceiptDialog(transaction: updated),
                                                  );
                                                }
                                              },
                                            ),
                                          if (order.status == 'diambil' || order.status == 'selesai')
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.print, size: 16),
                                              label: const Text('Struk'),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (_) => ReceiptDialog(transaction: order),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }
}
