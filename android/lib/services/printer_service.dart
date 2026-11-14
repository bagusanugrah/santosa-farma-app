import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._internal();
  PrinterService._internal();

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  String generateReceiptText(TransactionModel trx, {int paperWidth = 32}) {
    final buffer = StringBuffer();
    final divider = '=' * paperWidth;
    final dashLine = '-' * paperWidth;

    void addCentered(String text) {
      if (text.length >= paperWidth) {
        buffer.writeln(text);
      } else {
        final pad = ((paperWidth - text.length) / 2).floor();
        buffer.writeln(' ' * pad + text);
      }
    }

    void addRow(String left, String right) {
      final available = paperWidth - right.length;
      if (left.length > available) {
        left = left.substring(0, available - 1);
      }
      final space = paperWidth - left.length - right.length;
      buffer.writeln(left + (' ' * (space > 0 ? space : 1)) + right);
    }

    // Header
    addCentered('APOTEK SANTOSA FARMA');
    addCentered('Jl. Raya Jalancagak, Subang');
    addCentered('Telp / WA: 0812-3456-7890');
    buffer.writeln(divider);

    // Metadata
    addRow('No. Invoice', trx.invoiceNo);
    addRow('Waktu', dateFormat.format(trx.createdAt));
    addRow('Kanal', trx.channel == 'online' ? 'PESANAN WEB' : 'KASIR TOKO');
    addRow('Metode', trx.paymentMethod.toUpperCase());
    if (trx.customerName != null) {
      addRow('Pelanggan', trx.customerName!);
    }
    buffer.writeln(dashLine);

    // Items
    for (final item in trx.items) {
      buffer.writeln(item.productName);
      final qtyPrice = '${item.qty} x ${currencyFormat.format(item.price)}';
      final subtotal = currencyFormat.format(item.subtotal);
      addRow('  $qtyPrice', subtotal);
    }
    buffer.writeln(dashLine);

    // Totals
    addRow('TOTAL:', currencyFormat.format(trx.total));
    if (trx.amountPaid != null && trx.amountPaid! > 0) {
      addRow('Bayar:', currencyFormat.format(trx.amountPaid!));
      addRow('Kembali:', currencyFormat.format(trx.changeAmount ?? 0));
    }
    addRow('Status:', 'LUNAS (${trx.status.toUpperCase()})');
    buffer.writeln(divider);

    // Footer
    addCentered('Terima kasih atas kunjungan Anda');
    addCentered('Semoga Lekas Sembuh & Sehat Selalu');
    buffer.writeln('\n\n');

    return buffer.toString();
  }

  Future<void> shareReceipt(TransactionModel trx) async {
    final text = generateReceiptText(trx);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Struk Pembelian - ${trx.invoiceNo}',
      ),
    );
  }
}
