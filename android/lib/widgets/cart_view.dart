import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import 'payment_dialog.dart';

class CartView extends StatelessWidget {
  final bool isBottomSheet;

  const CartView({super.key, this.isBottomSheet = false});

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<PosProvider>();
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final cartItems = posProvider.cart.values.toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isBottomSheet ? const BorderRadius.vertical(top: Radius.circular(24)) : BorderRadius.circular(20),
        border: isBottomSheet ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: isBottomSheet
            ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -4))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cart Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined, color: Color(0xFF047857), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Keranjang Kasir',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${posProvider.totalItemsInCart}',
                        style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                if (cartItems.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Kosongkan', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => posProvider.clearCart(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Items List
          Expanded(
            child: cartItems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 48, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 8),
                        Text(
                          'Keranjang masih kosong',
                          style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Klik obat di katalog untuk menambahkan',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currency.format(item.product.price),
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFF64748B)),
                                onPressed: () => posProvider.decrementQty(item.product.id),
                              ),
                              Text(
                                '${item.qty}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF059669)),
                                onPressed: () => posProvider.addToCart(item.product),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              currency.format(item.subtotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Total & Checkout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF64748B))),
                    Text(
                      currency.format(posProvider.grandTotal),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF047857)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.payments, size: 18),
                    label: const Text('Proses Pembayaran (F12)'),
                    onPressed: cartItems.isEmpty
                        ? null
                        : () {
                            if (isBottomSheet) {
                              Navigator.of(context).pop(); // close sheet first
                            }
                            showDialog(
                              context: context,
                              builder: (_) => PaymentDialog(grandTotal: posProvider.grandTotal),
                            );
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
