import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/web_orders_provider.dart';
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

    final webOrders = context.read<WebOrdersProvider>();
    final trimmed = rawCode.trim();

    try {
      final trx = await webOrders.verifyPickup(trimmed);
      if (trx != null && mounted) {
        Navigator.of(context).pop(); // close scanner screen
        showDialog(
          context: context,
          builder: (_) => ReceiptDialog(transaction: trx),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${trx.invoiceNo} berhasil diserah-terimakan!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kode QR atau Invoice tidak ditemukan atau belum lunas.'),
              backgroundColor: Colors.red,
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
              await _controller.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Viewport
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
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
                // Scanner Frame Overlay
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF059669), width: 3),
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
            ),
          ),

          // Manual Code Input
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
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
                              hintText: 'Contoh: PKP-ABC123XYZ atau INV-...',
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
            ),
          ),
        ],
      ),
    );
  }
}
