import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transaction.dart';
import '../providers/web_orders_provider.dart';
import '../services/supabase_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filterOrders(List<TransactionModel> allOrders, int tabIndex) {
    var activeOrders = allOrders.where((o) => o.status != 'dibatalkan').toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final cleanQDigits = q.replaceAll(RegExp(r'[^0-9]'), '');

      activeOrders = activeOrders.where((o) {
        final matchInvoice = o.invoiceNo.toLowerCase().contains(q);
        final matchName = (o.customerName ?? '').toLowerCase().contains(q);

        final cleanPhone = (o.customerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        final matchPhone = (cleanQDigits.isNotEmpty && cleanPhone.contains(cleanQDigits)) ||
            (o.customerPhone ?? '').toLowerCase().contains(q);

        final matchItems = o.items.any((item) => item.productName.toLowerCase().contains(q));

        return matchInvoice || matchName || matchPhone || matchItems;
      }).toList();
    }

    switch (tabIndex) {
      case 1: // Belum Dibayar (Pending)
        return activeOrders.where((o) => o.status == 'pending').toList();
      case 2: // Siap Diambil (Lunas)
        return activeOrders.where((o) => o.status == 'paid').toList();
      case 3: // Sudah Diambil / Selesai
        return activeOrders.where((o) => o.status == 'diambil' || o.status == 'selesai').toList();
      default:
        return activeOrders;
    }
  }

  Future<void> _confirmDeleteOrder(BuildContext context, TransactionModel order, WebOrdersProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan & Hapus Pesanan?'),
        content: Text('Pesanan ${order.invoiceNo} akan dibatalkan dan dihapus secara permanen.'),
        actions: [
          TextButton(
            child: const Text('Kembali'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Hapus Pesanan'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.instance.cancelWebOrder(order.id);
      provider.loadOrders();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${order.invoiceNo} telah dihapus permanen.'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus pesanan: $e'), backgroundColor: Colors.red),
        );
      }
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
        // Top Action Bar: Search Bar + Scan QR + Refresh
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari no. invoice (INV-...), nama, atau HP...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0891B2)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF0891B2), width: 1.5),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
              ),
              const SizedBox(height: 10),

              // Action Buttons Row: Scan QR & Refresh
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text(
                        'Scan QR Pengambilan Obat',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0E7490),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    tooltip: 'Muat Ulang Pesanan',
                    icon: const Icon(Icons.refresh, color: Color(0xFF0E7490)),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      padding: const EdgeInsets.all(10),
                    ),
                    onPressed: () => webOrdersProvider.loadOrders(),
                  ),
                ],
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
              Tab(text: 'Semua (${_filterOrders(webOrdersProvider.orders, 0).length})'),
              Tab(text: 'Belum Dibayar (${_filterOrders(webOrdersProvider.orders, 1).length})'),
              Tab(text: 'Siap Diambil (${_filterOrders(webOrdersProvider.orders, 2).length})'),
              Tab(text: 'Sudah Selesai (${_filterOrders(webOrdersProvider.orders, 3).length})'),
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
                              Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
                                size: 56,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Pesanan tidak ditemukan'
                                    : 'Belum ada transaksi di tab ini',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tidak ada pesanan dengan kata kunci "$_searchQuery" di tab ini.'
                                    : 'Pesanan online yang masuk melalui website akan otomatis tampil di sini',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                              if (_searchQuery.isNotEmpty && tabIndex != 0) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.search, size: 16),
                                  label: const Text('Cari di Tab "Semua"'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0891B2),
                                    side: const BorderSide(color: Color(0xFF0891B2)),
                                  ),
                                  onPressed: () => _tabController.animateTo(0),
                                ),
                              ],
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
                                          if (order.status == 'pending') ...[
                                            IconButton(
                                              tooltip: 'Batalkan & Hapus Pesanan',
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              onPressed: () => _confirmDeleteOrder(context, order, webOrdersProvider),
                                            ),
                                            const SizedBox(width: 4),
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
                                          ],
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
