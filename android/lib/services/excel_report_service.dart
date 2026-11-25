import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';

class ExcelReportService {
  static final ExcelReportService instance = ExcelReportService._internal();
  ExcelReportService._internal();

  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final dateOnlyFormat = DateFormat('dd MMMM yyyy', 'id_ID');

  /// Membuat file Excel (.xlsx) dengan template profesional untuk laporan apotek
  Future<File> generateSalesReportExcel({
    required List<TransactionModel> transactions,
    required String selectedRange,
    required String selectedChannel,
  }) async {
    final excel = Excel.createExcel();

    // 1. Buat Sheet 1: Ringkasan & Transaksi
    const sheet1Name = 'Ringkasan & Transaksi';
    final sheet1 = excel[sheet1Name];
    excel.setDefaultSheet(sheet1Name);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    _buildSheet1SummaryAndTransactions(
      sheet: sheet1,
      transactions: transactions,
      selectedRange: selectedRange,
      selectedChannel: selectedChannel,
    );

    // 2. Buat Sheet 2: Rincian Item Obat Terjual
    const sheet2Name = 'Rincian Obat Terjual';
    final sheet2 = excel[sheet2Name];
    _buildSheet2ItemizedSales(
      sheet: sheet2,
      transactions: transactions,
      selectedRange: selectedRange,
    );

    // 3. Buat Sheet 3: Produk Terlaris (Ranking)
    const sheet3Name = 'Produk Terlaris';
    final sheet3 = excel[sheet3Name];
    _buildSheet3TopProducts(
      sheet: sheet3,
      transactions: transactions,
      selectedRange: selectedRange,
    );

    // Encode dan simpan file Excel
    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Gagal membuat dokumen Excel.');
    }

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Laporan_Penjualan_Santosa_Farma_$dateStr.xlsx');
    await file.writeAsBytes(fileBytes);

    return file;
  }

  // ===========================================================================
  // SHEET 1: RINGKASAN & TRANSAKSI
  // ===========================================================================
  void _buildSheet1SummaryAndTransactions({
    required Sheet sheet,
    required List<TransactionModel> transactions,
    required String selectedRange,
    required String selectedChannel,
  }) {
    // Set column widths
    sheet.setColumnWidth(0, 6.0);   // No
    sheet.setColumnWidth(1, 24.0);  // No. Invoice
    sheet.setColumnWidth(2, 20.0);  // Tanggal & Waktu
    sheet.setColumnWidth(3, 16.0);  // Kanal
    sheet.setColumnWidth(4, 20.0);  // Metode Bayar
    sheet.setColumnWidth(5, 18.0);  // Status
    sheet.setColumnWidth(6, 22.0);  // Pelanggan
    sheet.setColumnWidth(7, 12.0);  // Jml Item
    sheet.setColumnWidth(8, 22.0);  // Total Penjualan

    final borderThin = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#CBD5E1'),
    );

    final borderMedium = Border(
      borderStyle: BorderStyle.Medium,
      borderColorHex: ExcelColor.fromHexString('#0891B2'),
    );

    // Hitung Metrik
    final validTrx = transactions.where((t) => t.status == 'selesai' || t.status == 'diambil' || t.status == 'paid').toList();
    final double totalOmset = validTrx.fold(0.0, (sum, t) => sum + t.total);
    final int totalCount = transactions.length;

    final double kasirOmset = validTrx.where((t) => t.channel == 'toko').fold(0.0, (sum, t) => sum + t.total);
    final int kasirCount = transactions.where((t) => t.channel == 'toko').length;

    final double webOmset = validTrx.where((t) => t.channel == 'online').fold(0.0, (sum, t) => sum + t.total);
    final int webCount = transactions.where((t) => t.channel == 'online').length;

    final double tunaiOmset = validTrx.where((t) => t.paymentMethod == 'tunai').fold(0.0, (sum, t) => sum + t.total);
    final int tunaiCount = transactions.where((t) => t.paymentMethod == 'tunai').length;

    final double qrisOmset = validTrx.where((t) => t.paymentMethod != 'tunai').fold(0.0, (sum, t) => sum + t.total);
    final int qrisCount = transactions.where((t) => t.paymentMethod != 'tunai').length;

    final double aov = validTrx.isNotEmpty ? (totalOmset / validTrx.length) : 0.0;

    // Row 0: Banner Utama
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0),
      customValue: TextCellValue('APOTEK SANTOSA FARMA'),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0E7490'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Row 1: Subtitle
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1),
      customValue: TextCellValue('LAPORAN PENJUALAN & REKAPITULASI KEUANGAN'),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#0891B2'),
      backgroundColorHex: ExcelColor.fromHexString('#ECFEFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Row 2: Info Periode & Waktu Cetak
    final rangeText = _getRangeLabel(selectedRange);
    final channelText = _getChannelLabel(selectedChannel);
    final printTime = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
      CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 2),
      customValue: TextCellValue('Periode: $rangeText  |  Filter Kanal: $channelText  |  Waktu Export: $printTime WIB'),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#475569'),
      backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Row 4: Header Ringkasan Eksekutif
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 4),
      customValue: TextCellValue('RINGKASAN EKSEKUTIF (EXECUTIVE SUMMARY)'),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0369A1'),
      backgroundColorHex: ExcelColor.fromHexString('#E0F2FE'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderMedium,
      rightBorder: borderMedium,
      topBorder: borderMedium,
    );

    // Helper untuk cell ringkasan
    void setSummaryRow({
      required int row,
      required String lbl1,
      required String val1,
      required String lbl2,
      required String val2,
      bool highlight1 = false,
      bool highlight2 = false,
    }) {
      final styleLbl = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#334155'),
        backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
        leftBorder: borderThin,
        bottomBorder: borderThin,
      );
      final styleVal1 = CellStyle(
        bold: highlight1,
        fontSize: 10,
        fontColorHex: highlight1 ? ExcelColor.fromHexString('#0E7490') : ExcelColor.black,
        backgroundColorHex: highlight1 ? ExcelColor.fromHexString('#ECFEFF') : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Right,
        rightBorder: borderThin,
        bottomBorder: borderThin,
      );
      final styleVal2 = CellStyle(
        bold: highlight2,
        fontSize: 10,
        fontColorHex: highlight2 ? ExcelColor.fromHexString('#15803D') : ExcelColor.black,
        backgroundColorHex: highlight2 ? ExcelColor.fromHexString('#F0FDF4') : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Right,
        rightBorder: borderThin,
        bottomBorder: borderThin,
      );

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(lbl1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = styleLbl;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(val1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = styleVal1;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue('');

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
        customValue: TextCellValue(lbl2),
      );
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).cellStyle = styleLbl;

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row),
        customValue: TextCellValue(val2),
      );
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).cellStyle = styleVal2;
    }

    setSummaryRow(
      row: 5,
      lbl1: 'Total Omset Penjualan',
      val1: currency.format(totalOmset),
      lbl2: 'Penjualan Kasir (Toko)',
      val2: '${currency.format(kasirOmset)} ($kasirCount trx)',
      highlight1: true,
      highlight2: true,
    );

    setSummaryRow(
      row: 6,
      lbl1: 'Total Transaksi Tercatat',
      val1: '$totalCount Transaksi',
      lbl2: 'Penjualan Pesanan Web',
      val2: '${currency.format(webOmset)} ($webCount trx)',
      highlight2: true,
    );

    setSummaryRow(
      row: 7,
      lbl1: 'Rata-Rata Nilai Belanja (AOV)',
      val1: currency.format(aov),
      lbl2: 'Pembayaran Tunai (Cash)',
      val2: '${currency.format(tunaiOmset)} ($tunaiCount trx)',
    );

    setSummaryRow(
      row: 8,
      lbl1: 'Transaksi Lunas/Selesai',
      val1: '${validTrx.length} Transaksi',
      lbl2: 'Pembayaran QRIS / Midtrans',
      val2: '${currency.format(qrisOmset)} ($qrisCount trx)',
    );

    // Row 11: Header Tabel Transaksi
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 10)).value =
        TextCellValue('DAFTAR TRANSAKSI PENJUALAN');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 10)).cellStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#0E7490'),
    );

    final headers = [
      'No.',
      'No. Invoice',
      'Tanggal & Waktu',
      'Kanal',
      'Metode Bayar',
      'Status Transaksi',
      'Pelanggan',
      'Jml Item',
      'Total Penjualan (Rp)',
    ];

    const headerRow = 11;
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0891B2'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRow));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // Rows Data Transaksi
    int currentRow = 12;
    for (int i = 0; i < transactions.length; i++) {
      final trx = transactions[i];
      final isZebra = i % 2 == 1;
      final bg = isZebra ? ExcelColor.fromHexString('#F8FAFC') : ExcelColor.white;

      final rowStyleLeft = CellStyle(
        fontSize: 10,
        backgroundColorHex: bg,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderThin,
        rightBorder: borderThin,
        topBorder: borderThin,
        bottomBorder: borderThin,
      );

      final rowStyleCenter = CellStyle(
        fontSize: 10,
        backgroundColorHex: bg,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderThin,
        rightBorder: borderThin,
        topBorder: borderThin,
        bottomBorder: borderThin,
      );

      final rowStyleRight = CellStyle(
        fontSize: 10,
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#0E7490'),
        backgroundColorHex: bg,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderThin,
        rightBorder: borderThin,
        topBorder: borderThin,
        bottomBorder: borderThin,
      );

      final itemCount = trx.items.fold(0, (sum, it) => sum + it.qty);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(trx.invoiceNo);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).cellStyle = rowStyleLeft;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value =
          TextCellValue(dateFormat.format(trx.createdAt));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value =
          TextCellValue(trx.isOnline ? 'Pesanan Web' : 'Kasir Toko');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value =
          TextCellValue(trx.paymentMethod.toUpperCase());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value =
          TextCellValue(_formatStatus(trx.status));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value =
          TextCellValue(trx.customerName ?? (trx.isOnline ? 'Pelanggan Web' : 'Umum (Toko)'));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).cellStyle = rowStyleLeft;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow)).value = IntCellValue(itemCount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow)).value = DoubleCellValue(trx.total);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow)).cellStyle = rowStyleRight;

      currentRow++;
    }

    // Row Footer Total
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow),
      customValue: TextCellValue('TOTAL OMSET KESELURUHAN (STATUS VALID/LUNAS):'),
    );
    final footerLabelStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#0E7490'),
      backgroundColorHex: ExcelColor.fromHexString('#CFFAFE'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderMedium,
      topBorder: borderMedium,
      bottomBorder: borderMedium,
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = footerLabelStyle;

    final footerValStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0E7490'),
      backgroundColorHex: ExcelColor.fromHexString('#CFFAFE'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      rightBorder: borderMedium,
      topBorder: borderMedium,
      bottomBorder: borderMedium,
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow)).value = DoubleCellValue(totalOmset);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow)).cellStyle = footerValStyle;
  }

  // ===========================================================================
  // SHEET 2: RINCIAN ITEM OBAT TERJUAL
  // ===========================================================================
  void _buildSheet2ItemizedSales({
    required Sheet sheet,
    required List<TransactionModel> transactions,
    required String selectedRange,
  }) {
    // Set column widths
    sheet.setColumnWidth(0, 6.0);   // No
    sheet.setColumnWidth(1, 24.0);  // No. Invoice
    sheet.setColumnWidth(2, 20.0);  // Tanggal Transaksi
    sheet.setColumnWidth(3, 34.0);  // Nama Obat
    sheet.setColumnWidth(4, 18.0);  // Harga Satuan
    sheet.setColumnWidth(5, 14.0);  // Qty Terjual
    sheet.setColumnWidth(6, 22.0);  // Subtotal

    final borderThin = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#CBD5E1'),
    );
    final borderMedium = Border(
      borderStyle: BorderStyle.Medium,
      borderColorHex: ExcelColor.fromHexString('#0E7490'),
    );

    // Banner Sheet 2
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0),
      customValue: TextCellValue('APOTEK SANTOSA FARMA — RINCIAN OBAT TERJUAL'),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0E7490'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1),
      customValue: TextCellValue('Periode: ${_getRangeLabel(selectedRange)} | Dicetak: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())} WIB'),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#475569'),
      backgroundColorHex: ExcelColor.fromHexString('#ECFEFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Headers
    final headers = [
      'No.',
      'No. Invoice',
      'Tanggal Transaksi',
      'Nama Obat / Produk',
      'Harga Satuan (Rp)',
      'Qty Terjual',
      'Subtotal (Rp)',
    ];

    const headerRow = 3;
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0E7490'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRow));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    int itemIndex = 1;
    int currentRow = 4;
    int totalQty = 0;
    double totalSubtotal = 0.0;

    for (final trx in transactions) {
      for (final item in trx.items) {
        final isZebra = itemIndex % 2 == 1;
        final bg = isZebra ? ExcelColor.fromHexString('#F8FAFC') : ExcelColor.white;

        final rowStyleLeft = CellStyle(
          fontSize: 10,
          backgroundColorHex: bg,
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borderThin,
          rightBorder: borderThin,
          topBorder: borderThin,
          bottomBorder: borderThin,
        );

        final rowStyleCenter = CellStyle(
          fontSize: 10,
          backgroundColorHex: bg,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borderThin,
          rightBorder: borderThin,
          topBorder: borderThin,
          bottomBorder: borderThin,
        );

        final rowStyleRight = CellStyle(
          fontSize: 10,
          backgroundColorHex: bg,
          horizontalAlign: HorizontalAlign.Right,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borderThin,
          rightBorder: borderThin,
          topBorder: borderThin,
          bottomBorder: borderThin,
        );

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = IntCellValue(itemIndex);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = rowStyleCenter;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(trx.invoiceNo);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).cellStyle = rowStyleLeft;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value =
            TextCellValue(dateFormat.format(trx.createdAt));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).cellStyle = rowStyleCenter;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = TextCellValue(item.productName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).cellStyle = rowStyleLeft;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = DoubleCellValue(item.price);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).cellStyle = rowStyleRight;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = IntCellValue(item.qty);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).cellStyle = rowStyleCenter;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = DoubleCellValue(item.subtotal);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).cellStyle = rowStyleRight;

        totalQty += item.qty;
        totalSubtotal += item.subtotal;
        itemIndex++;
        currentRow++;
      }
    }

    // Footer Total Itemized
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
      customValue: TextCellValue('TOTAL PENJUALAN OBAT:'),
    );
    final footerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#0E7490'),
      backgroundColorHex: ExcelColor.fromHexString('#CFFAFE'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderMedium,
      topBorder: borderMedium,
      bottomBorder: borderMedium,
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = footerStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = IntCellValue(totalQty);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).cellStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#CFFAFE'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      topBorder: borderMedium,
      bottomBorder: borderMedium,
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = DoubleCellValue(totalSubtotal);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0E7490'),
      backgroundColorHex: ExcelColor.fromHexString('#CFFAFE'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      rightBorder: borderMedium,
      topBorder: borderMedium,
      bottomBorder: borderMedium,
    );
  }

  // ===========================================================================
  // SHEET 3: PRODUK TERLARIS (RANKING)
  // ===========================================================================
  void _buildSheet3TopProducts({
    required Sheet sheet,
    required List<TransactionModel> transactions,
    required String selectedRange,
  }) {
    sheet.setColumnWidth(0, 10.0); // Ranking
    sheet.setColumnWidth(1, 38.0); // Nama Obat
    sheet.setColumnWidth(2, 20.0); // Total Qty
    sheet.setColumnWidth(3, 24.0); // Total Omset
    sheet.setColumnWidth(4, 20.0); // Kontribusi %

    final borderThin = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#CBD5E1'),
    );

    // Banner
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0),
      customValue: TextCellValue('APOTEK SANTOSA FARMA — RANKING OBAT TERLARIS'),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#15803D'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1),
      customValue: TextCellValue('Berdasarkan kuantitas obat terjual pada periode ${_getRangeLabel(selectedRange)}'),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#166534'),
      backgroundColorHex: ExcelColor.fromHexString('#F0FDF4'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Aggregasi produk
    final Map<String, int> productQtyMap = {};
    final Map<String, double> productRevenueMap = {};
    double grandTotalRevenue = 0.0;

    for (final trx in transactions) {
      for (final it in trx.items) {
        final name = it.productName.trim();
        productQtyMap[name] = (productQtyMap[name] ?? 0) + it.qty;
        productRevenueMap[name] = (productRevenueMap[name] ?? 0.0) + it.subtotal;
        grandTotalRevenue += it.subtotal;
      }
    }

    // Urutkan dari kuantitas terbanyak
    final sortedProducts = productQtyMap.keys.toList()
      ..sort((a, b) => productQtyMap[b]!.compareTo(productQtyMap[a]!));

    // Headers
    final headers = [
      'Peringkat',
      'Nama Obat / Produk',
      'Total Terjual (Qty)',
      'Total Omset Produk (Rp)',
      'Kontribusi Penjualan (%)',
    ];

    const headerRow = 3;
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#15803D'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRow));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    int currentRow = 4;
    for (int i = 0; i < sortedProducts.length; i++) {
      final name = sortedProducts[i];
      final qty = productQtyMap[name]!;
      final revenue = productRevenueMap[name]!;
      final percentage = grandTotalRevenue > 0 ? ((revenue / grandTotalRevenue) * 100).toStringAsFixed(1) : '0.0';

      final isTop3 = i < 3;
      final bg = isTop3
          ? ExcelColor.fromHexString('#FEF9C3') // Soft gold highlight for top 3
          : (i % 2 == 1 ? ExcelColor.fromHexString('#F8FAFC') : ExcelColor.white);

      final rowStyleCenter = CellStyle(
        fontSize: 10,
        bold: isTop3,
        backgroundColorHex: bg,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderThin,
        rightBorder: borderThin,
        topBorder: borderThin,
        bottomBorder: borderThin,
      );

      final rowStyleLeft = CellStyle(
        fontSize: 10,
        bold: isTop3,
        backgroundColorHex: bg,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderThin,
        rightBorder: borderThin,
        topBorder: borderThin,
        bottomBorder: borderThin,
      );

      final rowStyleRight = CellStyle(
        fontSize: 10,
        bold: isTop3,
        backgroundColorHex: bg,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderThin,
        rightBorder: borderThin,
        topBorder: borderThin,
        bottomBorder: borderThin,
      );

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
          TextCellValue(isTop3 ? '🏆 Ke-${i + 1}' : 'Ke-${i + 1}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).cellStyle = rowStyleLeft;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = IntCellValue(qty);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = DoubleCellValue(revenue);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).cellStyle = rowStyleRight;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = TextCellValue('$percentage%');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).cellStyle = rowStyleCenter;

      currentRow++;
    }
  }

  String _getRangeLabel(String range) {
    switch (range) {
      case 'today':
        return 'Hari Ini (${dateOnlyFormat.format(DateTime.now())})';
      case '7days':
        return '7 Hari Terakhir';
      case '30days':
        return '30 Hari Terakhir';
      case 'all':
        return 'Semua Waktu';
      default:
        return range;
    }
  }

  String _getChannelLabel(String channel) {
    switch (channel) {
      case 'toko':
        return 'Kasir Toko (Offline)';
      case 'online':
        return 'Pesanan Web (Online)';
      default:
        return 'Semua Kanal (Gabungan Toko & Web)';
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'paid':
        return 'Lunas (Siap Diambil)';
      case 'diambil':
        return 'Sudah Diambil';
      case 'selesai':
        return 'Selesai';
      case 'pending':
        return 'Belum Dibayar';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return status.toUpperCase();
    }
  }
}
