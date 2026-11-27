import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/store_provider.dart';
import '../services/printer_service.dart';

class ReceiptDialog extends StatelessWidget {
  final TransactionModel transaction;

  const ReceiptDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'id_ID');
    final storeSetting = context.watch<StoreProvider>().setting;
    final storeAddress = storeSetting.storeAddress.trim();
    final storePhone = storeSetting.storePhone.trim();

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
                Center(
                  child: Column(
                    children: [
                      const Text('APOTEK SANTOSA FARMA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      if (storeAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          storeAddress,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                      if (storePhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Telp/WA: $storePhone',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 24),

                // Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('No. Invoice', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        transaction.invoiceNo,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Metode Bayar', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        transaction.paymentMethod.toUpperCase(),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Waktu', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dateFormat.format(transaction.createdAt),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
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
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0E7490)),
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
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Bagikan'),
          onPressed: () {
            PrinterService.instance.shareReceiptPdf(
              transaction,
              storeAddress: storeAddress,
              storePhone: storePhone,
            );
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Simpan PDF'),
          onPressed: () async {
            try {
              final savedPath = await PrinterService.instance.saveReceiptPdf(
                transaction,
                storeAddress: storeAddress,
                storePhone: storePhone,
              );
              if (savedPath != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Struk PDF (${transaction.invoiceNo}) berhasil disimpan.'),
                    backgroundColor: const Color(0xFF0891B2),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menyimpan struk PDF: $e'), backgroundColor: Colors.red),
                );
              }
            }
          },
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0891B2)),
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Preview / Cetak'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: Text('Struk ${transaction.invoiceNo}'),
                  ),
                  body: PdfPreview(
                    build: (_) => PrinterService.instance.generateReceiptPdf(
                      transaction,
                      storeAddress: storeAddress,
                      storePhone: storePhone,
                    ),
                    initialPageFormat: PdfPageFormat.roll80,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    dynamicLayout: false,
                    pdfFileName: 'Struk_${transaction.invoiceNo}.pdf',
                  ),
                ),
              ),
            );
          },
        ),
        TextButton(
          child: const Text('Tutup', style: TextStyle(color: Color(0xFF64748B))),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
