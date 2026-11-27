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
      if (_selectedPaymentMethod != 'all' && t.paymentMethod != _selectedPaymentMethod) {
        return false;
      }
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

  Widget _buildFilterChip(String label, String value, String currentValue, ValueChanged<String> onSelected) {
    final isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: const Color(0xFFCFFAFE),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? const Color(0xFF0E7490) : const Color(0xFF475569),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0),
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSummaryBar() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PENJUALAN',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currency.format(_totalOmset),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0E7490)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TUNAI LACI',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currency.format(_totalCash),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'QRIS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currency.format(_totalQris),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;

    return Column(
      children: [
        // 1. Search Bar & Filter Chips (No blue banner!)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari no. invoice atau nama obat...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 8),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Hari Ini', 'today', _selectedRange, (v) {
                      setState(() => _selectedRange = v);
                      _loadTransactions();
                    }),
                    const SizedBox(width: 6),
                    _buildFilterChip('7 Hari', '7days', _selectedRange, (v) {
                      setState(() => _selectedRange = v);
                      _loadTransactions();
                    }),
                    const SizedBox(width: 6),
                    _buildFilterChip('30 Hari', '30days', _selectedRange, (v) {
                      setState(() => _selectedRange = v);
                      _loadTransactions();
                    }),
                    const SizedBox(width: 6),
                    _buildFilterChip('Semua', 'all', _selectedRange, (v) {
                      setState(() => _selectedRange = v);
                      _loadTransactions();
                    }),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 18, color: const Color(0xFFCBD5E1)),
                    const SizedBox(width: 10),
                    _buildFilterChip('Semua Cara Bayar', 'all', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('Tunai', 'tunai', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('QRIS', 'qris', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                  ],
                ),
              ),
            ],
          ),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // 2. Compact 3-Column Summary Bar (Never truncated!)
        _buildSummaryBar(),

        // 3. Section Header
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
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
                    visualDensity: VisualDensity.compact,
                    onPressed: _loadTransactions,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. Transactions List
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
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            const Text(
                              'Belum ada transaksi di periode ini',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final trx = filtered[index];
                          final isCash = trx.paymentMethod == 'tunai';

                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
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
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Row 1: Invoice & Total
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                trx.invoiceNo,
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                dateFormat.format(trx.createdAt),
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              currency.format(trx.total),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0E7490),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isCash ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isCash ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isCash ? 'TUNAI' : 'QRIS',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: isCash ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
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
                                                  child: const Text(
                                                    'SELESAI',
                                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),

                                    // Items List
                                    if (trx.items.isNotEmpty) ...[
                                      ...trx.items.take(3).map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: Row(
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
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      if (trx.items.length > 3)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '+ ${trx.items.length - 3} obat lainnya...',
                                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                    ],

                                    // Cash details (if tunai)
                                    if (isCash && (trx.amountPaid ?? 0) > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Bayar: ${currency.format(trx.amountPaid ?? 0)}   •   Kembali: ${currency.format(trx.changeAmount ?? 0)}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                      // Footer Action Button
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 34),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          side: const BorderSide(color: Color(0xFF0891B2)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        icon: const Icon(Icons.print_outlined, size: 14, color: Color(0xFF0891B2)),
                                        label: const Text(
                                          'Lihat Rincian & Cetak Struk (PDF)',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => ReceiptDialog(transaction: trx),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
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
