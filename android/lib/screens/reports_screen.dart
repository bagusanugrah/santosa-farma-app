import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
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
  String _selectedRange = 'today'; // 'today', '7days', '30days', 'all'
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

  double get totalOmset => _transactions
      .where((t) => t.status == 'selesai' || t.status == 'diambil' || t.status == 'paid')
      .fold(0.0, (sum, t) => sum + t.total);

  int get totalTrx => _transactions.length;

  int get cashCount => _transactions.where((t) => t.paymentMethod == 'tunai').length;
  int get qrisCount => _transactions.where((t) => t.paymentMethod == 'qris').length;
  int get onlineCount => _transactions.where((t) => t.channel == 'online').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Range Filter Buttons
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text('Periode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('Hari Ini', 'today'),
                      const SizedBox(width: 8),
                      _buildChip('7 Hari', '7days'),
                      const SizedBox(width: 8),
                      _buildChip('30 Hari', '30days'),
                      const SizedBox(width: 8),
                      _buildChip('Semua Waktu', 'all'),
                    ],
                  ),
                ),
              ),
              IconButton(
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                Text('${_transactions.length} tercatat', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                else if (_transactions.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Belum ada transaksi di periode ini',
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
                          final trx = _transactions[index];
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
                                    subtitle: Row(
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
                                        Text(
                                          '${trx.paymentMethod.toUpperCase()} • ${trx.status.toUpperCase()}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                        ),
                                      ],
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
                        childCount: _transactions.length,
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
