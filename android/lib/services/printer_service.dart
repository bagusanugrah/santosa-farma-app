import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart';
import 'supabase_service.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._internal();
  PrinterService._internal();

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');

  /// Membuat dokumen PDF struk resmi Apotek Santosa Farma
  Future<Uint8List> generateReceiptPdf(
    TransactionModel trx, {
    PdfPageFormat? pageFormat,
    String? storeAddress,
    String? storePhone,
  }) async {
    String resolvedAddress = (storeAddress ?? '').trim();
    String resolvedPhone = (storePhone ?? '').trim();

    if (storeAddress == null || storePhone == null) {
      try {
        final setting = await SupabaseService.instance.getStoreSetting();
        resolvedAddress = (storeAddress ?? setting.storeAddress).trim();
        resolvedPhone = (storePhone ?? setting.storePhone).trim();
      } catch (_) {}
    }

    final pdf = pw.Document();

    pw.Font? regularFont;
    pw.Font? boldFont;

    try {
      regularFont = await PdfGoogleFonts.poppinsRegular();
      boldFont = await PdfGoogleFonts.poppinsBold();
    } catch (e) {
      debugPrint('[PDF Font Warning]: $e');
    }

    // Selalu gunakan ukuran kertas struk thermal (default 80mm, tinggi mengikuti isi struk)
    // agar tidak melebar ke ukuran A4/Letter meskipun dipanggil dari spooler sistem.
    final bool isThermalParam =
        pageFormat != null && pageFormat.width <= 95 * PdfPageFormat.mm;
    final targetFormat = isThermalParam ? pageFormat : PdfPageFormat.roll80;
    final useMultiPage = !targetFormat.height.isInfinite;

    const pageMargin = pw.EdgeInsets.symmetric(
      horizontal: 10.0,
      vertical: 12.0,
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
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (resolvedAddress.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                resolvedAddress,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ],
            if (resolvedPhone.isNotEmpty)
              pw.Text(
                'Telp/WA: $resolvedPhone',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

      // Metadata Transaksi
      _pdfRow('No. Invoice', trx.invoiceNo, isBold: true, fontSize: 7.5),
      _pdfRow('Waktu', dateFormat.format(trx.createdAt), fontSize: 7.5),
      _pdfRow(
        'Kanal',
        trx.channel == 'online' ? 'PESANAN WEB' : 'KASIR TOKO',
        fontSize: 7.5,
      ),
      _pdfRow('Metode', trx.paymentMethod.toUpperCase(), isBold: true, fontSize: 7.5),
      if (trx.customerName != null && trx.customerName!.isNotEmpty)
        _pdfRow('Pelanggan', trx.customerName!, fontSize: 7.5),
      if (trx.cashierId != null)
        _pdfRow('ID Kasir', '#${trx.cashierId}', fontSize: 7.5),

      pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
      pw.SizedBox(height: 4),

      // Daftar Item Obat
      ...trx.items.map((item) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                item.productName,
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${item.qty} x ${currencyFormat.format(item.price)}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                    ),
                  ),
                  pw.SizedBox(width: 8),
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
        _pdfRow('Tunai Diterima', currencyFormat.format(trx.amountPaid!), fontSize: 7.5),
        _pdfRow(
          'Kembalian',
          currencyFormat.format(trx.changeAmount ?? 0),
          isBold: true,
          fontSize: 7.5,
        ),
      ],
      _pdfRow('Status', 'LUNAS', isBold: true, fontSize: 7.5),

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

  /// 1. Cetak Struk via Spooler Android (tetap memaksa layout ukuran struk 80mm)
  Future<void> printReceipt(
    TransactionModel trx, {
    String? storeAddress,
    String? storePhone,
  }) async {
    await Printing.layoutPdf(
      format: PdfPageFormat.roll80,
      dynamicLayout: false,
      onLayout: (PdfPageFormat format) async => generateReceiptPdf(
        trx,
        storeAddress: storeAddress,
        storePhone: storePhone,
      ),
      name: 'Struk_${trx.invoiceNo}.pdf',
    );
  }

  /// 2. Simpan File PDF Ukuran Struk Asli (80mm) lewat File Picker Android
  Future<String?> saveReceiptPdf(
    TransactionModel trx, {
    String? storeAddress,
    String? storePhone,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      trx,
      storeAddress: storeAddress,
      storePhone: storePhone,
    );
    return FilePicker.saveFile(
      dialogTitle: 'Simpan Struk PDF',
      fileName: 'Struk_${trx.invoiceNo}.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: pdfBytes,
    );
  }

  /// 3. Download / Simpan Langsung File PDF ke Folder Dokumen HP
  Future<File> downloadReceiptPdf(
    TransactionModel trx, {
    String? storeAddress,
    String? storePhone,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      trx,
      storeAddress: storeAddress,
      storePhone: storePhone,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Struk_${trx.invoiceNo}.pdf');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  /// 4. Bagikan Dokumen Asli PDF Ukuran Struk (80mm) ke WhatsApp, Email, Telegram, dll.
  Future<void> shareReceiptPdf(
    TransactionModel trx, {
    String? storeAddress,
    String? storePhone,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      trx,
      storeAddress: storeAddress,
      storePhone: storePhone,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Struk_${trx.invoiceNo}.pdf',
    );
  }
}
