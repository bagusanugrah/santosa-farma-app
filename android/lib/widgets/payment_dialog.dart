import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import 'quick_cash_buttons.dart';
import 'receipt_dialog.dart';

class PaymentDialog extends StatefulWidget {
  final double grandTotal;

  const PaymentDialog({super.key, required this.grandTotal});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _cashController = TextEditingController();
  double _cashAmount = 0.0;
  bool _isProcessing = false;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cashAmount = widget.grandTotal;
    _cashController.text = widget.grandTotal.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  double get changeAmount => _cashAmount >= widget.grandTotal ? _cashAmount - widget.grandTotal : 0.0;

  Future<void> _processPayment(String method) async {
    if (method == 'tunai' && _cashAmount < widget.grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal uang tunai kurang dari total belanja!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final posProvider = context.read<PosProvider>();
    final authProvider = context.read<AuthProvider>();

    try {
      final trx = await posProvider.checkout(
        paymentMethod: method,
        amountPaid: method == 'tunai' ? _cashAmount : widget.grandTotal,
        changeAmount: method == 'tunai' ? changeAmount : 0.0,
        cashierId: authProvider.currentUser?.id,
      );

      if (mounted) {
        Navigator.of(context).pop(); // close payment dialog
        showDialog(
          context: context,
          builder: (_) => ReceiptDialog(transaction: trx),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses pembayaran: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pembayaran Kasir',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Grand Total Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total yang Harus Dibayar', style: TextStyle(fontSize: 13, color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                  Text(
                    currency.format(widget.grandTotal),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF047857),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF059669),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.payments_outlined), text: 'Tunai (Cash)'),
                Tab(icon: Icon(Icons.qr_code_2), text: 'QRIS Midtrans'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Content
            SizedBox(
              height: 280,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Tunai
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Pilihan Uang Cepat:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        QuickCashButtons(
                          total: widget.grandTotal,
                          onAmountSelected: (val) {
                            setState(() {
                              _cashAmount = val;
                              _cashController.text = val.toStringAsFixed(0);
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _cashController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Uang Tunai Diterima',
                            prefixText: 'Rp ',
                          ),
                          onChanged: (val) {
                            setState(() {
                              _cashAmount = double.tryParse(val) ?? 0.0;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _cashAmount >= widget.grandTotal ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _cashAmount >= widget.grandTotal ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _cashAmount >= widget.grandTotal ? 'Kembalian:' : 'Uang Kurang:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _cashAmount >= widget.grandTotal ? const Color(0xFF15803D) : Colors.red[800],
                                ),
                              ),
                              Text(
                                _cashAmount >= widget.grandTotal
                                    ? currency.format(changeAmount)
                                    : '- ${currency.format(widget.grandTotal - _cashAmount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: _cashAmount >= widget.grandTotal ? const Color(0xFF16A34A) : Colors.red[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: QRIS
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        QrImageView(
                          data: '00020101021226580016ID.CO.SHOPEE.WWW01189360099800000000000208MOCKQRIS520458125303360540${widget.grandTotal.toInt()}5802ID5919Apotek Santosa Farma6006SUBANG6304',
                          version: QrVersions.auto,
                          size: 160.0,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Scan menggunakan BCA, Mandiri, GoPay, OVO, atau ShopeePay',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pay Button
            FilledButton.icon(
              icon: _isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isProcessing ? 'Memproses...' : 'Selesaikan Pembayaran & Cetak Struk'),
              onPressed: _isProcessing
                  ? null
                  : () {
                      final method = _tabController.index == 0 ? 'tunai' : 'qris';
                      _processPayment(method);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
