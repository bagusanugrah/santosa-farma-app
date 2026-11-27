import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/web_orders_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/process_web_order_dialog.dart';
import '../widgets/receipt_dialog.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String rawCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final trimmed = rawCode.trim();

    try {
      final trx = await SupabaseService.instance.findOrderByQrOrInvoice(trimmed);
      if (trx == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kode QR atau Invoice tidak ditemukan di sistem.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // 1. If order is already completed/picked up
      if (trx.status == 'diambil' || trx.status == 'selesai') {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (_) => ReceiptDialog(transaction: trx),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${trx.invoiceNo} sudah selesai diambil sebelumnya.'),
            backgroundColor: const Color(0xFF0891B2),
          ),
        );
        return;
      }

      // 2. If order is PENDING -> Only Bayar di Kasir can be edited/paid at cashier
      if (trx.status == 'pending') {
        if (trx.isPayAtPharmacy) {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (_) => ProcessWebOrderDialog(order: trx),
          );
        } else {
          await context.read<WebOrdersProvider>().loadOrders();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Pesanan ${trx.invoiceNo} menunggu pembayaran online (Midtrans) dan tidak bisa diproses di kasir.',
                ),
                backgroundColor: Colors.orange[800],
              ),
            );
          }
        }
        return;
      }

      // 3. If order is PAID via Midtrans -> Handover confirmation
      if (trx.status == 'paid') {
        final updated = await context.read<WebOrdersProvider>().verifyPickup(trimmed);
        if (updated != null && mounted) {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (_) => ReceiptDialog(transaction: updated),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pesanan online ${updated.invoiceNo} (LUNAS) berhasil diserah-terimakan!'),
              backgroundColor: const Color(0xFF0891B2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Pengambilan Obat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : Colors.grey,
            ),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
                if (mounted) setState(() => _isTorchOn = !_isTorchOn);
              } catch (e) {
                debugPrint('Torch error: $e');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () async {
              try {
                await _controller.switchCamera();
              } catch (e) {
                debugPrint('Camera switch error: $e');
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isLandscapeWide =
              outerConstraints.maxWidth > outerConstraints.maxHeight &&
              outerConstraints.maxWidth >= 600;

          final cameraViewport = LayoutBuilder(
            builder: (context, camConstraints) {
              final minDim = math.min(camConstraints.maxWidth, camConstraints.maxHeight);
              final frameSize = (minDim * 0.65).clamp(110.0, 240.0);

              return Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _controller,
                    errorBuilder: (context, error, child) {
                      return Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.all(24),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_off, size: 48, color: Colors.white70),
                              SizedBox(height: 12),
                              Text(
                                'Kamera Tidak Dapat Diakses',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Pastikan izin kamera telah diberikan di pengaturan perangkat Anda, atau gunakan input kode manual di bawah.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _handleCode(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                  // Adaptive Scanner Frame Overlay
                  Container(
                    width: frameSize,
                    height: frameSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF0891B2), width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              );
            },
          );

          final manualInputPanel = Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Atau Masukkan Kode / No. Invoice Manual:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          decoration: const InputDecoration(
                            hintText: 'PKP-... atau INV-...',
                            prefixIcon: Icon(Icons.qr_code),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _isProcessing
                            ? null
                            : () {
                                if (_manualController.text.isNotEmpty) {
                                  _handleCode(_manualController.text);
                                }
                              },
                        child: const Text('Verifikasi'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Arahkan kamera ke layar ponsel pelanggan yang menampilkan QR Pengambilan dari web Apotek Santosa Farma.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          );

          if (isLandscapeWide) {
            return Row(
              children: [
                Expanded(flex: 3, child: cameraViewport),
                Expanded(flex: 2, child: manualInputPanel),
              ],
            );
          }

          return Column(
            children: [
              Expanded(flex: 3, child: cameraViewport),
              Expanded(flex: 2, child: manualInputPanel),
            ],
          );
        },
      ),
    );
  }
}
