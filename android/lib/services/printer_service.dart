import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._internal();
  PrinterService._internal();

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');

  /// Membuat dokumen PDF struk resmi Apotek Santosa Farma
  Future<Uint8List> generateReceiptPdf(
    TransactionModel trx, {
    PdfPageFormat? pageFormat,
  }) async {
    final pdf = pw.Document();

    pw.Font? regularFont;
    pw.Font? boldFont;

    try {
      regularFont = await PdfGoogleFonts.poppinsRegular();
      boldFont = await PdfGoogleFonts.poppinsBold();
    } catch (e) {
      debugPrint('[PDF Font Warning]: $e');
    }

    final targetFormat = pageFormat ?? PdfPageFormat.roll80;
    final isThermal = targetFormat.width <= 95 * PdfPageFormat.mm;
    final useMultiPage = !targetFormat.height.isInfinite;

    // Pada kertas lebar (misal ISO A4/Letter di Print Spooler Android),
    // pusatkan struk secara simetris di tengah halaman agar tidak menceng ke kiri.
    final double receiptWidth = isThermal
        ? (targetFormat.width - 24).clamp(120.0, targetFormat.width)
        : (targetFormat.width * 0.62).clamp(240.0, 360.0);
    final double sideMargin = isThermal
        ? 12.0
        : ((targetFormat.width - receiptWidth) / 2).clamp(20.0, targetFormat.width / 3);
    final double verticalMargin = isThermal ? 14.0 : 28.0;
    final double fontScale = isThermal ? 1.0 : 1.35;

    final pageMargin = pw.EdgeInsets.symmetric(
      horizontal: sideMargin,
      vertical: verticalMargin,
    );
    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    final contentWidgets = <pw.Widget>[
      // Header Apotek
      pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              'APOTEK SANTOSA FARMA',
              style: pw.TextStyle(
                fontSize: 12 * fontScale,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2 * fontScale),
            pw.Text(
              'Pertigaan Jl. Raya Jalancagak, Subang',
              style: pw.TextStyle(fontSize: 8 * fontScale, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'Telp/WA: 0857-2227-0120 | IG: @santosafarma',
              style: pw.TextStyle(fontSize: 7 * fontScale, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6 * fontScale),
      pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

      // Metadata Transaksi
      _pdfRow('No. Invoice', trx.invoiceNo, isBold: true, fontSize: 7.5 * fontScale),
      _pdfRow('Waktu', dateFormat.format(trx.createdAt), fontSize: 7.5 * fontScale),
      _pdfRow(
        'Kanal',
        trx.channel == 'online' ? 'PESANAN WEB' : 'KASIR TOKO',
        fontSize: 7.5 * fontScale,
      ),
      _pdfRow('Metode', trx.paymentMethod.toUpperCase(), isBold: true, fontSize: 7.5 * fontScale),
      if (trx.customerName != null && trx.customerName!.isNotEmpty)
        _pdfRow('Pelanggan', trx.customerName!, fontSize: 7.5 * fontScale),
      if (trx.cashierId != null)
        _pdfRow('ID Kasir', '#${trx.cashierId}', fontSize: 7.5 * fontScale),

      pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
      pw.SizedBox(height: 4 * fontScale),

      // Daftar Item Obat
      ...trx.items.map((item) {
        return pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 2.5 * fontScale),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                item.productName,
                style: pw.TextStyle(fontSize: 8.5 * fontScale, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${item.qty} x ${currencyFormat.format(item.price)}',
                      style: pw.TextStyle(fontSize: 8 * fontScale, color: PdfColors.grey800),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    currencyFormat.format(item.subtotal),
                    style: pw.TextStyle(fontSize: 8 * fontScale, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      }),

      pw.SizedBox(height: 4 * fontScale),
      pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

      // Rincian Pembayaran & Kembalian
      _pdfRow('TOTAL', currencyFormat.format(trx.total), isBold: true, fontSize: 10 * fontScale),
      if (trx.amountPaid != null && trx.amountPaid! > 0) ...[
        _pdfRow('Tunai Diterima', currencyFormat.format(trx.amountPaid!), fontSize: 7.5 * fontScale),
        _pdfRow(
          'Kembalian',
          currencyFormat.format(trx.changeAmount ?? 0),
          isBold: true,
          fontSize: 7.5 * fontScale,
        ),
      ],
      _pdfRow('Status', 'LUNAS', isBold: true, fontSize: 7.5 * fontScale),

      pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
      pw.SizedBox(height: 6 * fontScale),

      // Footer Struk
      pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              'Terima Kasih Atas Kunjungan Anda',
              style: pw.TextStyle(fontSize: 8 * fontScale, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2 * fontScale),
            pw.Text(
              'Semoga Lekas Sembuh & Sehat Selalu',
              style: pw.TextStyle(fontSize: 7 * fontScale, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 3 * fontScale),
            pw.Text(
              'Obat yang dibeli tidak dapat ditukar/dikembalikan',
              style: pw.TextStyle(fontSize: 6 * fontScale, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
    ];

    if (useMultiPage) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: targetFormat,
          margin: pageMargin,
          theme: theme,
          build: (pw.Context context) => contentWidgets,
        ),
      );
    } else {
      pdf.addPage(
        pw.Page(
          pageFormat: targetFormat,
          margin: pageMargin,
          theme: theme,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: contentWidgets,
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value, {bool isBold = false, double fontSize = 7.5}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Cetak Struk via Spooler Android (Bisa pilih Printer Fisik atau "Simpan sebagai PDF / Download")
  Future<void> printReceipt(TransactionModel trx) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async =>
          generateReceiptPdf(trx, pageFormat: format),
      name: 'Struk_${trx.invoiceNo}.pdf',
    );
  }

  /// 2. Download / Simpan Langsung File PDF ke Folder Dokumen HP
  Future<File> downloadReceiptPdf(TransactionModel trx) async {
    final pdfBytes = await generateReceiptPdf(trx);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Struk_${trx.invoiceNo}.pdf');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  /// 3. Bagikan Dokumen Asli PDF (Bukan Teks Mentah) ke WhatsApp, Email, Telegram, dll.
  Future<void> shareReceiptPdf(TransactionModel trx) async {
    final pdfBytes = await generateReceiptPdf(trx);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Struk_${trx.invoiceNo}.pdf',
    );
  }
}
