import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../services/excel_report_service.dart';
import '../services/supabase_service.dart';
import '../widgets/receipt_dialog.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String _selectedRange = 'today'; // 'today', '7days', '30days', 'all'
  String _selectedChannel = 'all'; // 'all', 'toko', 'online'
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    DateTime? from;
    final now = DateTime.now();

    if (_selectedRange == 'today') {
      from = DateTime(now.year, now.month, now.day);
    } else if (_selectedRange == '7days') {
      from = now.subtract(const Duration(days: 7));
    } else if (_selectedRange == '30days') {
      from = now.subtract(const Duration(days: 30));
    }

    try {
      _transactions = await SupabaseService.instance.getTransactionsForReport(fromDate: from);
    } catch (e) {
      debugPrint('Reports Error: $e');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<TransactionModel> get _displayedTransactions {
    if (_selectedChannel == 'all') return _transactions;
    return _transactions.where((t) => t.channel == _selectedChannel).toList();
  }

  double get totalOmset => _transactions
      .where((t) => t.status == 'selesai' || t.status == 'diambil' || t.status == 'paid')
      .fold(0.0, (sum, t) => sum + t.total);

  double get kasirOmset => _transactions
      .where((t) => t.channel == 'toko' && (t.status == 'selesai' || t.status == 'diambil' || t.status == 'paid'))
      .fold(0.0, (sum, t) => sum + t.total);

  double get webOmset => _transactions
      .where((t) => t.channel == 'online' && (t.status == 'selesai' || t.status == 'diambil' || t.status == 'paid'))
      .fold(0.0, (sum, t) => sum + t.total);

  int get totalTrx => _transactions.length;
  int get kasirCount => _transactions.where((t) => t.channel == 'toko').length;
  int get onlineCount => _transactions.where((t) => t.channel == 'online').length;
  int get cashCount => _transactions.where((t) => t.paymentMethod == 'tunai').length;
  int get qrisCount => _transactions.where((t) => t.paymentMethod == 'qris').length;

  Future<void> _exportToExcel() async {
    final listToExport = _displayedTransactions;
    if (listToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data transaksi untuk diekspor pada filter ini.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final file = await ExcelReportService.instance.generateSalesReportExcel(
        transactions: listToExport,
        selectedRange: _selectedRange,
        selectedChannel: _selectedChannel,
      );

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Laporan Penjualan Apotek Santosa Farma (${_getRangeLabel(_selectedRange)})',
            subject: 'Laporan Penjualan Excel',
          ),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan Excel berhasil dibuat! Silakan buka di Excel atau bagikan.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor Excel: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _getRangeLabel(String range) {
    switch (range) {
      case 'today':
        return 'Hari Ini';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Range Filter Buttons & Export Action
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Text('Periode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('Hari Ini', 'today'),
                      const SizedBox(width: 6),
                      _buildChip('7 Hari', '7days'),
                      const SizedBox(width: 6),
                      _buildChip('30 Hari', '30days'),
                      const SizedBox(width: 6),
                      _buildChip('Semua Waktu', 'all'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: _isExporting
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.table_view_rounded, size: 16),
                label: const Text('Export Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_isLoading || _isExporting) ? null : _exportToExcel,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Muat Ulang',
                icon: const Icon(Icons.refresh, color: Color(0xFF0E7490)),
                onPressed: _loadReports,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Scrollable Body (Works cleanly in portrait, landscape phone, and tablet)
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReports,
            color: const Color(0xFF0891B2),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Summary Cards
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    'Total Omset Penjualan',
                                    currency.format(totalOmset),
                                    Icons.account_balance_wallet,
                                    const Color(0xFF0891B2),
                                    const Color(0xFFECFEFF),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricCard(
                                    'Total Transaksi',
                                    '$totalTrx Transaksi',
                                    Icons.receipt_long,
                                    const Color(0xFF2563EB),
                                    const Color(0xFFEFF6FF),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Channel Breakdown Pill
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: _buildSubMetric('Tunai (Cash)', '$cashCount')),
                                  const SizedBox(height: 24, child: VerticalDivider()),
                                  Expanded(child: _buildSubMetric('QRIS', '$qrisCount')),
                                  const SizedBox(height: 24, child: VerticalDivider()),
                                  Expanded(child: _buildSubMetric('Pesanan Web', '$onlineCount')),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Transactions History Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Riwayat Transaksi (Gabungan)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                    Text(
                                      _selectedChannel == 'all'
                                          ? '${_transactions.length} tercatat'
                                          : '${_displayedTransactions.length} dari ${_transactions.length} tercatat',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      const Text('Kanal: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                      ChoiceChip(
                                        label: Text('Semua ($totalTrx)'),
                                        selected: _selectedChannel == 'all',
                                        onSelected: (_) => setState(() => _selectedChannel = 'all'),
                                        selectedColor: const Color(0xFFCFFAFE),
                                        backgroundColor: Colors.white,
                                        labelStyle: TextStyle(
                                          fontSize: 11,
                                          fontWeight: _selectedChannel == 'all' ? FontWeight.bold : FontWeight.normal,
                                          color: _selectedChannel == 'all' ? const Color(0xFF0E7490) : const Color(0xFF475569),
                                        ),
                                        side: BorderSide(
                                          color: _selectedChannel == 'all' ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ChoiceChip(
                                        label: Text('Kasir Toko ($kasirCount)'),
                                        selected: _selectedChannel == 'toko',
                                        onSelected: (_) => setState(() => _selectedChannel = 'toko'),
                                        selectedColor: const Color(0xFFCFFAFE),
                                        backgroundColor: Colors.white,
                                        labelStyle: TextStyle(
                                          fontSize: 11,
                                          fontWeight: _selectedChannel == 'toko' ? FontWeight.bold : FontWeight.normal,
                                          color: _selectedChannel == 'toko' ? const Color(0xFF0E7490) : const Color(0xFF475569),
                                        ),
                                        side: BorderSide(
                                          color: _selectedChannel == 'toko' ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ChoiceChip(
                                        label: Text('Pesanan Web ($onlineCount)'),
                                        selected: _selectedChannel == 'online',
                                        onSelected: (_) => setState(() => _selectedChannel = 'online'),
                                        selectedColor: const Color(0xFFDBEAFE),
                                        backgroundColor: Colors.white,
                                        labelStyle: TextStyle(
                                          fontSize: 11,
                                          fontWeight: _selectedChannel == 'online' ? FontWeight.bold : FontWeight.normal,
                                          color: _selectedChannel == 'online' ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                        ),
                                        side: BorderSide(
                                          color: _selectedChannel == 'online' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0891B2))),
                  )
                else if (_displayedTransactions.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Belum ada transaksi di periode atau kanal ini',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final trx = _displayedTransactions[index];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Card(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: trx.isOnline ? const Color(0xFFEFF6FF) : const Color(0xFFECFEFF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        trx.isOnline ? Icons.shopping_bag : Icons.point_of_sale,
                                        color: trx.isOnline ? const Color(0xFF2563EB) : const Color(0xFF0891B2),
                                        size: 20,
                                      ),
                                    ),
                                    title: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            trx.invoiceNo,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          currency.format(trx.total),
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0E7490), fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              dateFormat.format(trx.createdAt),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: trx.isOnline ? const Color(0xFFEFF6FF) : const Color(0xFFECFEFF),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: trx.isOnline ? const Color(0xFFBFDBFE) : const Color(0xFFA5F3FC),
                                                  ),
                                                ),
                                                child: Text(
                                                  trx.isOnline ? 'WEB' : 'KASIR',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    color: trx.isOnline ? const Color(0xFF1D4ED8) : const Color(0xFF0E7490),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  trx.paymentMethod.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => ReceiptDialog(transaction: trx),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _displayedTransactions.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _selectedRange == value;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF0E7490) : const Color(0xFF475569),
      ),
      selectedColor: const Color(0xFFCFFAFE),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
      onSelected: (_) {
        setState(() => _selectedRange = value);
        _loadReports();
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubMetric(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
