import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../providers/pos_provider.dart';
import '../providers/web_orders_provider.dart';
import '../services/supabase_service.dart';
import 'payment_dialog.dart';

class EditableOrderItem {
  final int productId;
  final String productName;
  final double price;
  int qty;
  final int maxStock;

  EditableOrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.qty,
    required this.maxStock,
  });

  double get subtotal => price * qty;
}

class ProcessWebOrderDialog extends StatefulWidget {
  final TransactionModel order;

  const ProcessWebOrderDialog({super.key, required this.order});

  @override
  State<ProcessWebOrderDialog> createState() => _ProcessWebOrderDialogState();
}

class _ProcessWebOrderDialogState extends State<ProcessWebOrderDialog> {
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  late List<EditableOrderItem> _items;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    final posProducts = context.read<PosProvider>().products;
    final productStockMap = {for (var p in posProducts) p.id: p.stock};

    _items = widget.order.items.map((item) {
      final pId = item.productId ?? 0;
      final stock = productStockMap[pId] ?? 999;
      return EditableOrderItem(
        productId: pId,
        productName: item.productName,
        price: item.price,
        qty: item.qty,
        maxStock: stock,
      );
    }).toList();
  }

  double get _currentTotal => _items.fold(0.0, (sum, i) => sum + i.subtotal);
  int get _totalItemCount => _items.fold(0, (sum, i) => sum + i.qty);

  void _showAddProductPicker() {
    final posProvider = context.read<PosProvider>();
    final products = posProvider.products;
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = products.where((p) {
              return p.name.toLowerCase().contains(search.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tambah Obat ke Pesanan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari nama obat...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setSheetState(() => search = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Obat tidak ditemukan',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final p = filtered[index];
                                final isAlreadyIn = _items.any((i) => i.productId == p.id);

                                return ListTile(
                                  dense: true,
                                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text(
                                    '${currency.format(p.price)} • Stok: ${p.stock}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.stock <= 0 ? Colors.red : const Color(0xFF64748B),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      isAlreadyIn ? Icons.check_circle : Icons.add_circle,
                                      color: isAlreadyIn ? const Color(0xFF0891B2) : const Color(0xFF2563EB),
                                    ),
                                    onPressed: p.stock <= 0
                                        ? null
                                        : () {
                                            setState(() {
                                              final existingIndex = _items.indexWhere((i) => i.productId == p.id);
                                              if (existingIndex >= 0) {
                                                if (_items[existingIndex].qty < p.stock) {
                                                  _items[existingIndex].qty++;
                                                }
                                              } else {
                                                _items.add(EditableOrderItem(
                                                  productId: p.id,
                                                  productName: p.name,
                                                  price: p.price,
                                                  qty: 1,
                                                  maxStock: p.stock,
                                                ));
                                              }
                                            });
                                            Navigator.pop(ctx);
                                          },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan Web?'),
        content: Text('Pesanan ${widget.order.invoiceNo} akan ditandai sebagai DIBATALKAN.'),
        actions: [
          TextButton(
            child: const Text('Kembali'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await SupabaseService.instance.cancelWebOrder(widget.order.id);
      if (mounted) {
        context.read<WebOrdersProvider>().loadOrders();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${widget.order.invoiceNo} telah dibatalkan.'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membatalkan pesanan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _proceedToPayment() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan tidak boleh kosong! Tambahkan minimal 1 obat.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Open PaymentDialog with custom checkout callback
    showDialog(
      context: context,
      builder: (_) => PaymentDialog(
        grandTotal: _currentTotal,
        onCustomCheckout: (method, amountPaid, changeAmount, cashierId) async {
          final itemsPayload = _items.map((item) {
            return {
              'product': Product(
                id: item.productId,
                name: item.productName,
                price: item.price,
                stock: item.maxStock,
              ),
              'qty': item.qty,
              'price': item.price,
              'subtotal': item.subtotal,
            };
          }).toList();

          final updatedTrx = await SupabaseService.instance.completeWebOrderAtPos(
            transactionId: widget.order.id,
            items: itemsPayload,
            total: _currentTotal,
            paymentMethod: method,
            amountPaid: amountPaid,
            changeAmount: changeAmount,
            cashierId: cashierId,
          );

          // Refresh providers
          if (mounted) {
            context.read<WebOrdersProvider>().loadOrders();
            context.read<PosProvider>().loadProducts();
            Navigator.of(context).pop(); // close ProcessWebOrderDialog
          }

          return updatedTrx;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0891B2), size: 20),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                widget.order.invoiceNo,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(widget.order.createdAt),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront, size: 14, color: Color(0xFFB45309)),
                        SizedBox(width: 4),
                        Text(
                          'Bayar di Kasir',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Customer Info Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.order.customerName ?? 'Pelanggan Web',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    if (widget.order.customerPhone != null) ...[
                      InkWell(
                        onTap: () {
                          final phone = widget.order.customerPhone!.replaceAll(RegExp(r'[^0-9]'), '');
                          launchUrl(Uri.parse('https://wa.me/$phone'));
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.chat, size: 14, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              widget.order.customerPhone!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Title & Add Product Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rincian Obat Pesanan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0891B2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Tambah Obat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _showAddProductPicker,
                  ),
                ],
              ),
              const Divider(height: 12),

              // Items List (Editable)
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_shopping_cart, size: 40, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            const Text(
                              'Semua item dihapus',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                            TextButton(
                              onPressed: _showAddProductPicker,
                              child: const Text('Tambah obat baru'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 8, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, index) {
                          final item = _items[index];

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${currency.format(item.price)} / unit',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Stepper Qty
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFF64748B)),
                                      onPressed: () {
                                        setState(() {
                                          if (item.qty > 1) {
                                            item.qty--;
                                          } else {
                                            _items.removeAt(index);
                                          }
                                        });
                                      },
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${item.qty}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF0891B2)),
                                      onPressed: () {
                                        setState(() {
                                          item.qty++;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),

                                // Subtotal
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    currency.format(item.subtotal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                ),

                                // Delete
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setState(() => _items.removeAt(index));
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const Divider(height: 20),

              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFEFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA5F3FC)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Penyesuaian ($_totalItemCount item)',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF155E75)),
                        ),
                        Text(
                          currency.format(_currentTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Color(0xFF0E7490),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.receipt_long, color: Color(0xFF0891B2), size: 28),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: _isCancelling
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Batalkan'),
                    onPressed: _isCancelling ? null : _handleCancelOrder,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0891B2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.point_of_sale, size: 18),
                      label: const Text(
                        'Bayar di Kasir (Tunai / QRIS)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _proceedToPayment,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
