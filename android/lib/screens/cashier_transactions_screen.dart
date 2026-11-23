import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';
import '../widgets/receipt_dialog.dart';

class CashierTransactionsScreen extends StatefulWidget {
  const CashierTransactionsScreen({super.key});

  @override
  State<CashierTransactionsScreen> createState() => _CashierTransactionsScreenState();
}

class _CashierTransactionsScreenState extends State<CashierTransactionsScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _selectedRange = 'today'; // 'today', '7days', '30days', 'all'
  String _selectedPaymentMethod = 'all'; // 'all', 'tunai', 'qris'
  String _searchQuery = '';
  RealtimeChannel? _subscription;

  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeRealtime() {
    final client = SupabaseService.instance.client;
    _subscription = client
        .channel('public:transactions_cashier_screen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) {
            try {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty && newRecord['channel'] == 'toko') {
                _loadTransactions();
              }
            } catch (_) {}
          },
        )
        .subscribe();
  }

  Future<void> _loadTransactions() async {
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
      final list = await SupabaseService.instance.getCashierTransactions(fromDate: from);
      if (mounted) {
        setState(() {
          _transactions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error load cashier transactions: $e');
    }
  }

  List<TransactionModel> get _filteredTransactions {
    return _transactions.where((t) {
      // Filter payment method
      if (_selectedPaymentMethod != 'all' && t.paymentMethod != _selectedPaymentMethod) {
        return false;
      }

      // Filter search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesInvoice = t.invoiceNo.toLowerCase().contains(q);
        final matchesItem = t.items.any((item) => item.productName.toLowerCase().contains(q));
        if (!matchesInvoice && !matchesItem) return false;
      }

      return true;
    }).toList();
  }

  double get _totalOmset => _filteredTransactions.fold(0.0, (sum, t) => sum + t.total);
  double get _totalCash => _filteredTransactions
      .where((t) => t.paymentMethod == 'tunai')
      .fold(0.0, (sum, t) => sum + t.total);
  double get _totalQris => _filteredTransactions
      .where((t) => t.paymentMethod == 'qris')
      .fold(0.0, (sum, t) => sum + t.total);

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, String currentValue, ValueChanged<String> onSelected) {
    final isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: const Color(0xFFCFFAFE),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF0E7490) : const Color(0xFF475569),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;

    return Column(
      children: [
        // Top info header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFECFEFF),
          child: const Row(
            children: [
              Icon(Icons.point_of_sale, size: 16, color: Color(0xFF0891B2)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daftar Transaksi Kasir Toko: Seluruh penjualan langsung di apotek tercatat di sini. Ketuk transaksi untuk melihat detail & cetak struk PDF.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF0E7490), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Search bar & Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari no. invoice (POS-...) atau nama obat...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0891B2)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 8),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Periode: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    _buildChip('Hari Ini', 'today', _selectedRange, (v) {
                      setState(() => _selectedRange = v);
                      _loadTransactions();
                    }),
                    const SizedBox(width: 6),
                    _buildChip('7 Hari', '7days', _selectedRange, (v) {
                      setState(() => _selectedRange = v);
                      _loadTransactions();
                    }),
                    const SizedBox(width: 6),
                    _buildChip('30 Hari', '30days', _selectedRange, (v) {
                      setState(() => _selectedRange = v);
                      _loadTransactions();
                    }),
                    const SizedBox(width: 6),
                    _buildChip('Semua', 'all', _selectedRange, (v) {
                      setState(() => _selectedRange = v);
                      _loadTransactions();
                    }),
                    const SizedBox(width: 14),
                    const Text('Metode: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    _buildChip('Semua', 'all', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                    const SizedBox(width: 6),
                    _buildChip('Tunai', 'tunai', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                    const SizedBox(width: 6),
                    _buildChip('QRIS', 'qris', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Summary Bar (Omset, Tunai di Laci, Jumlah)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Penjualan',
                  currency.format(_totalOmset),
                  Icons.receipt_long,
                  const Color(0xFF0E7490),
                  const Color(0xFFECFEFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  'Tunai di Laci',
                  currency.format(_totalCash),
                  Icons.payments_outlined,
                  const Color(0xFF16A34A),
                  const Color(0xFFDCFCE7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  'QRIS Kasir',
                  currency.format(_totalQris),
                  Icons.qr_code_2,
                  const Color(0xFF2563EB),
                  const Color(0xFFEFF6FF),
                ),
              ),
            ],
          ),
        ),

        // List Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Transaksi (${filtered.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF0891B2)),
                tooltip: 'Muat Ulang',
                onPressed: _loadTransactions,
              ),
            ],
          ),
        ),

        // Transactions List
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF0891B2),
            onRefresh: _loadTransactions,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0891B2)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada transaksi kasir pada periode ini',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Transaksi yang dilakukan di Kasir POS akan otomatis muncul di sini.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final trx = filtered[index];
                          final isCash = trx.paymentMethod == 'tunai';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ReceiptDialog(transaction: trx),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Header: Invoice No + Badges + Date
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFEFF),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.point_of_sale, size: 16, color: Color(0xFF0891B2)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                trx.invoiceNo,
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                dateFormat.format(trx.createdAt),
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Payment Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isCash ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isCash ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isCash ? Icons.payments_outlined : Icons.qr_code_2,
                                                size: 12,
                                                color: isCash ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isCash ? 'TUNAI' : 'QRIS',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: isCash ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Status Selesai badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'SELESAI',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18),

                                    // Items breakdown
                                    if (trx.items.isNotEmpty) ...[
                                      ...trx.items.take(3).map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 3),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${item.qty}x ${item.productName}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                currency.format(item.subtotal),
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      if (trx.items.length > 3)
                                        Text(
                                          '+ ${trx.items.length - 3} obat lainnya...',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                                        ),
                                      const SizedBox(height: 6),
                                    ],

                                    // Total & Change row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (isCash && (trx.amountPaid ?? 0) > 0)
                                          Text(
                                            'Diterima: ${currency.format(trx.amountPaid ?? 0)} • Kembali: ${currency.format(trx.changeAmount ?? 0)}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          )
                                        else
                                          const Text(
                                            'Pembayaran Non-Tunai QRIS',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                                          ),
                                        Text(
                                          currency.format(trx.total),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0E7490),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Action button
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          side: const BorderSide(color: Color(0xFF0891B2)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.receipt_long, size: 16, color: Color(0xFF0891B2)),
                                        label: const Text(
                                          'Lihat Rincian & Cetak Struk (PDF)',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => ReceiptDialog(transaction: trx),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
