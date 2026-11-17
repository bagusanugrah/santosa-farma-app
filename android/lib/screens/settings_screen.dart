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

  // Integration Controllers (Super Admin)
  late final TextEditingController _fonnteTokenCtrl;
  late final TextEditingController _fonnteUrlCtrl;
  late final TextEditingController _mailHostCtrl;
  late final TextEditingController _mailPortCtrl;
  late final TextEditingController _mailUsernameCtrl;
  late final TextEditingController _mailPasswordCtrl;
  late final TextEditingController _mailFromNameCtrl;
  late final TextEditingController _midtransClientKeyCtrl;
  late final TextEditingController _midtransServerKeyCtrl;
  bool _midtransIsProduction = false;
  bool _isSavingIntegrations = false;
  bool _obscureFonnte = true;
  bool _obscureMailPass = true;
  bool _obscureMidtrans = true;
  bool _initializedIntegrations = false;

  @override
  void initState() {
    super.initState();
    _fonnteTokenCtrl = TextEditingController();
    _fonnteUrlCtrl = TextEditingController();
    _mailHostCtrl = TextEditingController();
    _mailPortCtrl = TextEditingController();
    _mailUsernameCtrl = TextEditingController();
    _mailPasswordCtrl = TextEditingController();
    _mailFromNameCtrl = TextEditingController();
    _midtransClientKeyCtrl = TextEditingController();
    _midtransServerKeyCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedIntegrations) {
      final storeProvider = context.watch<StoreProvider>();
      if (!storeProvider.isLoading) {
        final setting = storeProvider.setting;
        _fonnteTokenCtrl.text = setting.fonnteToken;
        _fonnteUrlCtrl.text = setting.fonnteUrl;
        _mailHostCtrl.text = setting.mailHost;
        _mailPortCtrl.text = setting.mailPort.toString();
        _mailUsernameCtrl.text = setting.mailUsername;
        _mailPasswordCtrl.text = setting.mailPassword;
        _mailFromNameCtrl.text = setting.mailFromName;
        _midtransClientKeyCtrl.text = setting.midtransClientKey;
        _midtransServerKeyCtrl.text = setting.midtransServerKey;
        _midtransIsProduction = setting.midtransIsProduction;
        _initializedIntegrations = true;
      }
    }
  }

  @override
  void dispose() {
    _fonnteTokenCtrl.dispose();
    _fonnteUrlCtrl.dispose();
    _mailHostCtrl.dispose();
    _mailPortCtrl.dispose();
    _mailUsernameCtrl.dispose();
    _mailPasswordCtrl.dispose();
    _mailFromNameCtrl.dispose();
    _midtransClientKeyCtrl.dispose();
    _midtransServerKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSaveIntegrations() async {
    setState(() => _isSavingIntegrations = true);
    try {
      await context.read<StoreProvider>().updateIntegrationSettings(
            fonnteToken: _fonnteTokenCtrl.text,
            fonnteUrl: _fonnteUrlCtrl.text,
            mailHost: _mailHostCtrl.text,
            mailPort: int.tryParse(_mailPortCtrl.text) ?? 587,
            mailUsername: _mailUsernameCtrl.text,
            mailPassword: _mailPasswordCtrl.text,
            mailFromName: _mailFromNameCtrl.text,
            midtransClientKey: _midtransClientKeyCtrl.text,
            midtransServerKey: _midtransServerKeyCtrl.text,
            midtransIsProduction: _midtransIsProduction,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan WhatsApp, Email & Midtrans berhasil disimpan ke database!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan pengaturan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingIntegrations = false);
    }
  }

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
    final isSuperAdmin = auth.currentUser?.isSuperAdmin == true;

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

              // Super Admin Integration Settings Card
              if (isSuperAdmin) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.admin_panel_settings, color: Color(0xFF059669), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pengaturan Integrasi & Gateway',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                  Text(
                                    'Khusus Super Admin: Konfigurasi WhatsApp, Email, dan Midtrans tersimpan terpusat di Supabase.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Section 1: WhatsApp Fonnte
                        const Row(
                          children: [
                            Icon(Icons.chat_outlined, color: Color(0xFF16A34A), size: 18),
                            SizedBox(width: 8),
                            Text('WhatsApp Gateway (Fonnte)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _fonnteTokenCtrl,
                          obscureText: _obscureFonnte,
                          decoration: InputDecoration(
                            labelText: 'Fonnte Token API',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureFonnte ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _obscureFonnte = !_obscureFonnte),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fonnteUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Fonnte Endpoint URL',
                            hintText: 'https://api.fonnte.com/send',
                            isDense: true,
                          ),
                        ),
                        const Divider(height: 28),

                        // Section 2: Email SMTP (Gmail)
                        const Row(
                          children: [
                            Icon(Icons.email_outlined, color: Color(0xFFEA580C), size: 18),
                            SizedBox(width: 8),
                            Text('Email Gateway (Gmail SMTP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _mailHostCtrl,
                                decoration: const InputDecoration(labelText: 'SMTP Host', hintText: 'smtp.gmail.com', isDense: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _mailPortCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Port', hintText: '587', isDense: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mailUsernameCtrl,
                          decoration: const InputDecoration(labelText: 'Email Akun (Username)', hintText: 'kucitcloud@gmail.com', isDense: true),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mailPasswordCtrl,
                          obscureText: _obscureMailPass,
                          decoration: InputDecoration(
                            labelText: 'App Password Gmail (16 Karakter)',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureMailPass ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _obscureMailPass = !_obscureMailPass),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mailFromNameCtrl,
                          decoration: const InputDecoration(labelText: 'Nama Pengirim Email', hintText: 'Apotek Santosa Farma', isDense: true),
                        ),
                        const Divider(height: 28),

                        // Section 3: Midtrans Payment Gateway
                        const Row(
                          children: [
                            Icon(Icons.payment, color: Color(0xFF2563EB), size: 18),
                            SizedBox(width: 8),
                            Text('Payment Gateway (Midtrans Snap)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _midtransClientKeyCtrl,
                          decoration: const InputDecoration(labelText: 'Midtrans Client Key', isDense: true),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _midtransServerKeyCtrl,
                          obscureText: _obscureMidtrans,
                          decoration: InputDecoration(
                            labelText: 'Midtrans Server Key',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureMidtrans ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _obscureMidtrans = !_obscureMidtrans),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mode Production (Live)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            _midtransIsProduction ? 'Transaksi menggunakan uang asli (Production)' : 'Transaksi menggunakan simulasi Sandbox',
                            style: TextStyle(fontSize: 11, color: _midtransIsProduction ? Colors.red : const Color(0xFF2563EB)),
                          ),
                          value: _midtransIsProduction,
                          activeColor: Colors.red,
                          onChanged: (val) => setState(() => _midtransIsProduction = val),
                        ),
                        const SizedBox(height: 16),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _isSavingIntegrations
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save, size: 18),
                            label: Text(_isSavingIntegrations ? 'Menyimpan...' : 'Simpan Pengaturan Gateway'),
                            onPressed: _isSavingIntegrations ? null : _handleSaveIntegrations,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
