import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/store_provider.dart';
import '../services/backup_service.dart';
import '../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isResetting = false;

  Future<void> _handleBackup() async {
    setState(() => _isBackingUp = true);
    try {
      await BackupService.instance.shareBackupZip();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat backup: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);
    try {
      final success = await BackupService.instance.restoreFromPicker();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil dipulihkan dari file backup!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulihkan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _handleFactoryReset() async {
    final confirmController = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reset Pabrik Apotek?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tindakan ini akan menghapus semua riwayat transaksi, pesanan web, dan mengembalikan katalog obat ke data awal.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Text(
                'Sistem akan otomatis mencadangkan file ZIP ke memori sebelum penghapusan data dimulai.',
                style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Ketik "RESET" untuk konfirmasi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                hintText: 'Ketik RESET',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (confirmController.text.trim() == 'RESET') {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Lanjutkan Reset'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      setState(() => _isResetting = true);
      try {
        // 1. Safety backup first
        await BackupService.instance.createBackupZip();

        // 2. Factory reset
        await SupabaseService.instance.factoryReset();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reset Pabrik berhasil diselesaikan. Data telah kembali ke setelan awal.'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal reset pabrik: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isResetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final store = context.watch<StoreProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFECFDF5),
                        child: Text(
                          auth.currentUser?.name.substring(0, 1).toUpperCase() ?? 'K',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.currentUser?.name ?? 'Petugas Kasir',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Username: ${auth.currentUser?.username} • Role: ${auth.currentUser?.role}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Keluar'),
                        onPressed: () => auth.logout(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Store Settings Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pengaturan Toko & Website', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text(
                        'Kontrol ketersediaan apotek dan transaksi online pelanggan secara langsung.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Status Buka Apotek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          store.isOpen ? 'Apotek sedang BUKA dan melayani pembeli' : 'Apotek sedang TUTUP',
                          style: TextStyle(fontSize: 12, color: store.isOpen ? const Color(0xFF16A34A) : Colors.red),
                        ),
                        value: store.isOpen,
                        activeColor: const Color(0xFF059669),
                        onChanged: (val) => store.toggleStoreOpen(val),
                      ),
                      const Divider(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fitur Transaksi di Web Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          store.onlineOrdersEnabled
                              ? 'Pelanggan dapat checkout dan memesan obat via website'
                              : 'Transaksi online dinonaktifkan sementara (pelanggan hanya bisa melihat katalog)',
                          style: TextStyle(fontSize: 12, color: store.onlineOrdersEnabled ? const Color(0xFF2563EB) : Colors.amber[800]),
                        ),
                        value: store.onlineOrdersEnabled,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) => store.toggleOnlineOrders(val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Data Management (Backup, Restore, Reset)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cadangan & Pemulihan Data', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text(
                        'Amankan database transaksi, produk, dan pengaturan ke file ZIP atau simpan ke Google Drive.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF059669)),
                        ),
                        title: const Text('Cadangkan Database (ZIP / Drive)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Export seluruh data ke file ZIP dan bagikan ke Drive atau WhatsApp', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        trailing: FilledButton.icon(
                          icon: _isBackingUp ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.download, size: 16),
                          label: const Text('Backup'),
                          onPressed: _isBackingUp ? null : _handleBackup,
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.settings_backup_restore, color: Color(0xFF2563EB)),
                        ),
                        title: const Text('Pulihkan Data dari Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Pilih file ZIP atau JSON backup yang pernah Anda simpan', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        trailing: OutlinedButton.icon(
                          icon: _isRestoring ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.folder_open, size: 16),
                          label: const Text('Restore'),
                          onPressed: _isRestoring ? null : _handleRestore,
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.delete_forever, color: Colors.red),
                        ),
                        title: const Text('Reset Pabrik (Factory Reset)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                        subtitle: const Text('Hapus seluruh transaksi dan kembalikan stok obat ke data awal', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: _isResetting ? null : _handleFactoryReset,
                          child: _isResetting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Reset'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // App Version Info
              const Center(
                child: Column(
                  children: [
                    Text('Apotek Santosa Farma POS — Android Edition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    SizedBox(height: 2),
                    Text('Versi 1.0.0 (Material Design 3 + Supabase Cloud)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
