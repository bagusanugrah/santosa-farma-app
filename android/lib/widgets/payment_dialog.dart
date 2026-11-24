import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/store_provider.dart';
import '../services/supabase_service.dart';
import 'quick_cash_buttons.dart';
import 'receipt_dialog.dart';

class PaymentDialog extends StatefulWidget {
  final double grandTotal;
  final Future<TransactionModel> Function(
    String method,
    double amountPaid,
    double changeAmount,
    int? cashierId,
  )? onCustomCheckout;

  const PaymentDialog({
    super.key,
    required this.grandTotal,
    this.onCustomCheckout,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _cashController = TextEditingController();
  double _cashAmount = 0.0;
  bool _isProcessing = false;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // QRIS Realtime & Midtrans State
  Timer? _statusPollingTimer;
  String? _qrisOrderId;
  String? _qrisString;
  bool _isLoadingQris = false;
  bool _isCheckingStatus = false;
  bool _isDownloadingQr = false;
  String _qrisPaymentStatus = 'idle'; // 'idle', 'generating', 'waiting', 'paid', 'failed'
  String? _qrisErrorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _cashAmount = widget.grandTotal;
    _cashController.text = widget.grandTotal.toStringAsFixed(0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabController.index == 1 && _qrisString == null && mounted) {
        _initQrisCharge();
      }
    });
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {});
    if (_tabController.index == 1) {
      if (_qrisString == null && !_isLoadingQris) {
        _initQrisCharge();
      } else if (_qrisOrderId != null && _statusPollingTimer == null && _qrisPaymentStatus != 'paid') {
        _startPollingPaymentStatus();
      }
    } else {
      _statusPollingTimer?.cancel();
      _statusPollingTimer = null;
    }
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  double get changeAmount => _cashAmount >= widget.grandTotal ? _cashAmount - widget.grandTotal : 0.0;

  Future<void> _initQrisCharge() async {
    final storeProvider = context.read<StoreProvider>();
    if (!storeProvider.isMidtransValid) return;

    setState(() {
      _isLoadingQris = true;
      _qrisPaymentStatus = 'generating';
      _qrisErrorMsg = null;
    });

    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMddHHmmss').format(now);
    final randomSuffix = (100 + (now.microsecond % 900)).toString();
    _qrisOrderId = 'POS-QRIS-$dateStr-$randomSuffix';

    try {
      final res = await SupabaseService.instance.createMidtransQrisCharge(
        orderId: _qrisOrderId!,
        grossAmount: widget.grandTotal.toInt(),
        serverKey: storeProvider.setting.midtransServerKey,
        isProduction: storeProvider.setting.midtransIsProduction,
      );

      if (!mounted) return;

      if (res != null && res['qr_string'] != null) {
        setState(() {
          _qrisString = res['qr_string'];
          _isLoadingQris = false;
          _qrisPaymentStatus = 'waiting';
        });
        _startPollingPaymentStatus();
      } else {
        setState(() {
          _isLoadingQris = false;
          _qrisPaymentStatus = 'failed';
          _qrisErrorMsg = 'Gagal membuat QRIS Midtrans. Pastikan koneksi internet stabil.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingQris = false;
        _qrisPaymentStatus = 'failed';
        _qrisErrorMsg = 'Kesalahan saat menghubungi Midtrans: $e';
      });
    }
  }

  void _startPollingPaymentStatus() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkPaymentStatus(silent: true);
    });
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (!mounted || _isProcessing || _qrisOrderId == null) return;

    if (!silent) {
      setState(() => _isCheckingStatus = true);
    }

    final storeProvider = context.read<StoreProvider>();

    try {
      final res = await SupabaseService.instance.checkMidtransStatus(
        orderId: _qrisOrderId!,
        serverKey: storeProvider.setting.midtransServerKey,
        isProduction: storeProvider.setting.midtransIsProduction,
      );

      if (!mounted) return;

      final status = res?['transaction_status']?.toString().toLowerCase();
      final fraudStatus = res?['fraud_status']?.toString().toLowerCase();
      final isSettled = status == 'settlement' || (status == 'capture' && fraudStatus != 'challenge');

      if (isSettled) {
        _statusPollingTimer?.cancel();
        _statusPollingTimer = null;
        setState(() {
          _qrisPaymentStatus = 'paid';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran QRIS Berhasil Diterima! Menyelesaikan transaksi...'),
            backgroundColor: Color(0xFF0D9488),
            duration: Duration(seconds: 2),
          ),
        );

        // Auto finalize payment!
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted && !_isProcessing) {
          _processPayment('qris');
        }
      } else if (!silent) {
        final displayStatus = status ?? 'belum dibayar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status pembayaran saat ini: $displayStatus. Pelanggan belum melakukan pembayaran.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengecek status: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  Future<void> _downloadOrShareQris() async {
    if (_qrisString == null) return;

    setState(() => _isDownloadingQr = true);

    try {
      final painter = QrPainter(
        data: _qrisString!,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
      );

      final picData = await painter.toImageData(800, format: ui.ImageByteFormat.png);
      if (picData == null) {
        throw Exception('Gagal membuat gambar QR');
      }

      final bytes = picData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'QRIS_${_qrisOrderId ?? DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      // Try copying to standard Android Download folder if available
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final destFile = File('${downloadDir.path}/$fileName');
          await destFile.writeAsBytes(bytes);
        }
      } catch (_) {}

      // Open Share sheet so cashier/customer can save to gallery, m-banking, or share
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'QRIS Pembayaran Apotek Santosa Farma - Total ${currency.format(widget.grandTotal)}',
          subject: 'QRIS Pembayaran Apotek Santosa Farma',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gambar QRIS ($fileName) berhasil disimpan dan siap dibuka/dibagikan!'),
            backgroundColor: const Color(0xFF0E7490),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh gambar QRIS: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingQr = false);
      }
    }
  }

  Future<void> _processPayment(String method) async {
    if (method == 'qris') {
      final isMidtransValid = context.read<StoreProvider>().isMidtransValid;
      if (!isMidtransValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran QRIS gagal: Kredensial Midtrans belum dikonfigurasi secara valid di Pengaturan Toko.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
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
      final TransactionModel trx;
      if (widget.onCustomCheckout != null) {
        trx = await widget.onCustomCheckout!(
          method,
          method == 'tunai' ? _cashAmount : widget.grandTotal,
          method == 'tunai' ? changeAmount : 0.0,
          authProvider.currentUser?.id,
        );
      } else {
        trx = await posProvider.checkout(
          paymentMethod: method,
          amountPaid: method == 'tunai' ? _cashAmount : widget.grandTotal,
          changeAmount: method == 'tunai' ? changeAmount : 0.0,
          cashierId: authProvider.currentUser?.id,
        );
      }

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
    final isMidtransValid = context.watch<StoreProvider>().isMidtransValid;
    final isQrisLocked = _tabController.index == 1 && !isMidtransValid;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFEFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA5F3FC)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Total yang Harus Dibayar',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Color(0xFF155E75), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currency.format(widget.grandTotal),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0E7490)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF0E7490),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF0891B2),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  const Tab(icon: Icon(Icons.payments_outlined), text: 'Tunai (Cash)'),
                  Tab(
                    icon: Icon(isMidtransValid ? Icons.qr_code_2 : Icons.lock_outline),
                    text: isMidtransValid ? 'QRIS Midtrans' : 'QRIS (Terkunci)',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Content
              SizedBox(
                height: 380,
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
                              color: _cashAmount >= widget.grandTotal ? const Color(0xFFECFEFF) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _cashAmount >= widget.grandTotal ? const Color(0xFFA5F3FC) : const Color(0xFFFECACA),
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
                                    color: _cashAmount >= widget.grandTotal ? const Color(0xFF0E7490) : Colors.red[800],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _cashAmount >= widget.grandTotal
                                          ? currency.format(changeAmount)
                                          : '- ${currency.format(widget.grandTotal - _cashAmount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: _cashAmount >= widget.grandTotal ? const Color(0xFF0891B2) : Colors.red[800],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: QRIS
                    if (!isMidtransValid)
                      Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEF2F2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lock_outline, size: 44, color: Color(0xFFDC2626)),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Fitur QRIS Dinonaktifkan',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Kredensial Midtrans belum diisi atau belum valid di Pengaturan Toko. Demi keamanan kasir hanya dapat memproses pembayaran Tunai.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (_isLoadingQris)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0891B2)),
                            SizedBox(height: 16),
                            Text(
                              'Menyiapkan kode QRIS Midtrans...',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    else if (_qrisPaymentStatus == 'failed')
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 44, color: Colors.red),
                              const SizedBox(height: 10),
                              Text(
                                _qrisErrorMsg ?? 'Gagal memuat QRIS',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.red),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _initQrisCharge,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Enlarged QR Container
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: _qrisString ?? '',
                                  version: QrVersions.auto,
                                  size: 220.0,
                                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Realtime status badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _qrisPaymentStatus == 'paid'
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _qrisPaymentStatus == 'paid'
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_qrisPaymentStatus == 'paid')
                                      const Icon(Icons.check_circle, size: 16, color: Color(0xFF059669))
                                    else
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _qrisPaymentStatus == 'paid'
                                          ? 'Pembayaran Berhasil! Memproses...'
                                          : 'Menunggu scan & pembayaran QRIS...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _qrisPaymentStatus == 'paid'
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFF166534),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Scan menggunakan BCA, Mandiri, GoPay, OVO, ShopeePay, atau m-Banking.\nSistem otomatis menyelesaikan pesanan begitu pembayaran masuk.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions: Tunai vs QRIS
              if (_tabController.index == 0)
                // Tunai Mode: Selesaikan Pembayaran button
                FilledButton.icon(
                  style: isQrisLocked
                      ? FilledButton.styleFrom(backgroundColor: const Color(0xFF94A3B8))
                      : null,
                  icon: _isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isProcessing ? 'Memproses...' : 'Selesaikan Pembayaran & Cetak Struk',
                    ),
                  ),
                  onPressed: (_isProcessing || _cashAmount < widget.grandTotal)
                      ? null
                      : () => _processPayment('tunai'),
                )
              else
                // QRIS Mode: NO manual complete button! Replace with Download QRIS & Cek Status
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: (_isCheckingStatus || _isProcessing || !isMidtransValid || _qrisString == null)
                            ? null
                            : () => _checkPaymentStatus(silent: false),
                        icon: _isCheckingStatus
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Cek Status'),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: (_isDownloadingQr || !isMidtransValid || _qrisString == null)
                            ? null
                            : _downloadOrShareQris,
                        icon: _isDownloadingQr
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Download QRIS (Gambar)'),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0E7490),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
