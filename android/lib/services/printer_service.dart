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
  Future<Uint8List> generateReceiptPdf(TransactionModel trx) async {
    final pdf = pw.Document();

    pw.Font? regularFont;
    pw.Font? boldFont;

    try {
      regularFont = await PdfGoogleFonts.poppinsRegular();
      boldFont = await PdfGoogleFonts.poppinsBold();
    } catch (e) {
      debugPrint('[PDF Font Warning]: $e');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Apotek
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'APOTEK SANTOSA FARMA',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Pertigaan Jl. Raya Jalancagak, Subang',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      'Telp/WA: 0857-2227-0120 | IG: @santosafarma',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

              // Metadata Transaksi
              _pdfRow('No. Invoice', trx.invoiceNo, isBold: true),
              _pdfRow('Waktu', dateFormat.format(trx.createdAt)),
              _pdfRow('Kanal', trx.channel == 'online' ? 'PESANAN WEB' : 'KASIR TOKO'),
              _pdfRow('Metode', trx.paymentMethod.toUpperCase(), isBold: true),
              if (trx.customerName != null && trx.customerName!.isNotEmpty)
                _pdfRow('Pelanggan', trx.customerName!),
              if (trx.cashierId != null)
                _pdfRow('ID Kasir', '#${trx.cashierId}'),

              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Daftar Item Obat
              ...trx.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.productName,
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${item.qty} x ${currencyFormat.format(item.price)}',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                          ),
                          pw.Text(
                            currencyFormat.format(item.subtotal),
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

              // Rincian Pembayaran & Kembalian
              _pdfRow('TOTAL', currencyFormat.format(trx.total), isBold: true, fontSize: 10),
              if (trx.amountPaid != null && trx.amountPaid! > 0) ...[
                _pdfRow('Tunai Diterima', currencyFormat.format(trx.amountPaid!)),
                _pdfRow('Kembalian', currencyFormat.format(trx.changeAmount ?? 0), isBold: true),
              ],
              _pdfRow('Status', 'LUNAS', isBold: true),

              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 6),

              // Footer Struk
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Terima Kasih Atas Kunjungan Anda',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Semoga Lekas Sembuh & Sehat Selalu',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Obat yang dibeli tidak dapat ditukar/dikembalikan',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value, {bool isBold = false, double fontSize = 7.5}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Cetak Struk via Spooler Android (Bisa pilih Printer Fisik atau "Simpan sebagai PDF / Download")
  Future<void> printReceipt(TransactionModel trx) async {
    final pdfBytes = await generateReceiptPdf(trx);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
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
