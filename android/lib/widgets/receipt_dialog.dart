import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/printer_service.dart';

class ReceiptDialog extends StatelessWidget {
  final TransactionModel transaction;

  const ReceiptDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'id_ID');

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transaksi Berhasil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                Text('Struk Pembelian Kasir', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Center(
                  child: Column(
                    children: [
                      Text('APOTEK SANTOSA FARMA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Jl. Raya Jalancagak, Subang', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                const Divider(height: 24),

                // Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('No. Invoice', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(transaction.invoiceNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Metode Bayar', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(transaction.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Waktu', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(dateFormat.format(transaction.createdAt), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const Divider(height: 24),

                // Items
                ...transaction.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(
                                '${item.qty} x ${currency.format(item.price)}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Text(currency.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    Text(
                      currency.format(transaction.total),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF047857)),
                    ),
                  ],
                ),
                if (transaction.amountPaid != null && transaction.amountPaid! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tunai Diterima', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(currency.format(transaction.amountPaid!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kembalian', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(currency.format(transaction.changeAmount ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Cetak / Bagikan Struk'),
          onPressed: () {
            PrinterService.instance.shareReceipt(transaction);
          },
        ),
        FilledButton(
          child: const Text('Selesai'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
