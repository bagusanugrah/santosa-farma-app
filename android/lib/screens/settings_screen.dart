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
  bool _isCleaningStorage = false;

  // Ubah Password Controllers (Kasir & Super Admin)
  late final TextEditingController _oldPasswordCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;
  bool _isChangingPassword = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Integration Controllers (Khusus Super Admin)
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
  bool _isTestingMidtrans = false;
  bool _obscureFonnte = true;
  bool _obscureMailPass = true;
  bool _obscureMidtrans = true;
  bool _initializedIntegrations = false;

  @override
  void initState() {
    super.initState();
    _oldPasswordCtrl = TextEditingController();
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();

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
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();

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

  // ==========================================
  // UBAH PASSWORD
  // ==========================================
  Future<void> _handleChangePassword(int userId) async {
    final oldPass = _oldPasswordCtrl.text.trim();
    final newPass = _newPasswordCtrl.text.trim();
    final confirmPass = _confirmPasswordCtrl.text.trim();

    if (oldPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan password saat ini terlebih dahulu.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password baru minimal harus 6 karakter.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfirmasi password baru tidak cocok!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      await SupabaseService.instance.changeStaffPassword(
        userId: userId,
        oldPassword: oldPass,
        newPassword: newPass,
      );

      _oldPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password berhasil diperbarui! Gunakan password baru ini saat login.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  // ==========================================
  // INTEGRATIONS & BACKUP (SUPER ADMIN)
  // ==========================================
  Future<void> _handleTestMidtrans() async {
    setState(() => _isTestingMidtrans = true);
    final clientKey = _midtransClientKeyCtrl.text.trim();
    final serverKey = _midtransServerKeyCtrl.text.trim();

    if (clientKey.isEmpty || serverKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client Key dan Server Key Midtrans tidak boleh kosong.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
      setState(() => _isTestingMidtrans = false);
      return;
    }

    final isValid = await context.read<StoreProvider>().testMidtransConnection(
          clientKey: clientKey,
          serverKey: serverKey,
          isProduction: _midtransIsProduction,
        );

    if (mounted) {
      if (isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kredensial Midtrans Valid! Terhubung ke ${_midtransIsProduction ? "Production" : "Sandbox"} dengan sukses.',
            ),
            backgroundColor: const Color(0xFF0891B2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kredensial Midtrans Tidak Valid atau ditolak (${_midtransIsProduction ? "Production" : "Sandbox"}). Periksa Server Key.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isTestingMidtrans = false);
    }
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
            content: Text('Pengaturan integrasi gateway berhasil disimpan ke Supabase!'),
            backgroundColor: Color(0xFF0891B2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan integrasi: $e'),
            backgroundColor: Colors.red,
          ),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pulihkan Database?'),
        content: const Text(
          'Data produk, foto obat, transaksi, dan pengaturan akan dipulihkan dari file backup. File gambar lama yang tidak terhubung akan otomatis dibersihkan dari storage Supabase. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0891B2)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pilih File & Pulihkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);
    try {
      final cleanedCount = await BackupService.instance.restoreFromPicker();
      if (mounted) {
        if (cleanedCount != null) {
          final extraInfo = cleanedCount > 0
              ? ' ($cleanedCount file gambar lama yang tidak terhubung berhasil dibersihkan dari storage).'
              : ' (Storage sudah bersih dan sinkron).';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data berhasil dipulihkan dari file cadangan!$extraInfo'),
              backgroundColor: const Color(0xFF0891B2),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pemulihan dibatalkan atau tidak ada file dipilih.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulihkan data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _handleCleanStorage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bersihkan Storage Gambar?'),
        content: const Text(
          'Sistem akan memindai seluruh file gambar di Supabase Storage dan menghapus file gambar lama yang tidak terhubung dengan produk obat manapun.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0891B2)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mulai Pembersihan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCleaningStorage = true);
    try {
      final count = await SupabaseService.instance.cleanupOrphanProductImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Berhasil! $count gambar nyangkut di storage telah dibersihkan.'
                  : 'Storage Supabase sudah bersih! Tidak ada gambar yang nyangkut.',
            ),
            backgroundColor: const Color(0xFF0891B2),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membersihkan storage: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCleaningStorage = false);
    }
  }

  Future<void> _handleFactoryReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ PERINGATAN: Reset Pabrik', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Tindakan ini akan MENGHAPUS SEMUA TRANSAKSI dan mereset katalog obat ke data pabrik bawaan. '
          'Tindakan ini TIDAK DAPAT DIBATALKAN!\n\nApakah Anda benar-benar yakin?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Reset Semua Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResetting = true);
    try {
      await SupabaseService.instance.factoryReset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset pabrik selesai. Seluruh data transaksi dibersihkan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mereset: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: const Color(0xFF64748B),
          ),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }

  Widget _buildConfigField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: isPassword && obscure,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF64748B),
                        size: 18,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataActionTile({
    required bool isCompact,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? subtitle,
    Color? titleColor,
    required Widget actionButton,
  }) {
    final headerRow = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: titleColor ?? const Color(0xFF1E293B),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ],
          ),
        ),
        if (!isCompact) actionButton,
      ],
    );

    if (!isCompact) return headerRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerRow,
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: actionButton),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final store = context.watch<StoreProvider>();
    final currentUser = auth.currentUser;
    final isSuperAdmin = currentUser?.isSuperAdmin == true;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 520;
    final userName = currentUser?.name.trim() ?? '';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : (isSuperAdmin ? 'A' : 'K');

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. User Profile Card
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: isCompact ? 24 : 28,
                            backgroundColor: isSuperAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFECFEFF),
                            child: Text(
                              userInitial,
                              style: TextStyle(
                                fontSize: isCompact ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: isSuperAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF0891B2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName.isNotEmpty ? userName : (isSuperAdmin ? 'Super Admin' : 'Petugas Kasir'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Username: ${currentUser?.username ?? "-"} • Role: ${isSuperAdmin ? "Super Admin" : "Kasir Toko"}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('Keluar'),
                              onPressed: () => auth.logout(),
                            ),
                          ],
                        ],
                      ),
                      if (isCompact) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('Keluar dari Akun'),
                            onPressed: () => auth.logout(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Khusus Kasir: Pengaturan Operasional Toko & Website
              if (!isSuperAdmin) ...[
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFEFF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.storefront, color: Color(0xFF0891B2), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pengaturan Toko & Website',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                  Text(
                                    'Kontrol status buka toko dan ketersediaan transaksi online pelanggan.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          activeColor: const Color(0xFF0891B2),
                          onChanged: (val) => store.toggleStoreOpen(val),
                        ),
                        const Divider(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Fitur Transaksi di Web Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            store.onlineOrdersEnabled
                                ? (store.isMidtransValid
                                    ? 'Transaksi web aktif (Metode: Midtrans Online & Bayar di Apotek)'
                                    : 'Transaksi web aktif (Metode: Bayar di Apotek, Midtrans belum diisi)')
                                : 'Transaksi web dinonaktifkan sementara (pelanggan hanya bisa melihat katalog)',
                            style: TextStyle(
                              fontSize: 12,
                              color: store.onlineOrdersEnabled
                                  ? (store.isMidtransValid ? const Color(0xFF2563EB) : const Color(0xFF0891B2))
                                  : Colors.amber[800],
                            ),
                          ),
                          value: store.onlineOrdersEnabled,
                          activeColor: const Color(0xFF0891B2),
                          onChanged: (val) => store.toggleOnlineOrders(val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Card Keamanan Akun & Ubah Password (Untuk Kasir dan Admin)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.lock_reset, color: Color(0xFFD97706), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ubah Password ${isSuperAdmin ? "Admin" : "Kasir"}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                const Text(
                                  'Perbarui kata sandi login akun Anda untuk menjaga keamanan transaksi apotek.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildPasswordField(
                        controller: _oldPasswordCtrl,
                        label: 'Password Saat Ini',
                        hint: 'Masukkan password lama Anda',
                        obscureText: _obscureOldPassword,
                        onToggleObscure: () => setState(() => _obscureOldPassword = !_obscureOldPassword),
                      ),
                      const SizedBox(height: 12),
                      _buildPasswordField(
                        controller: _newPasswordCtrl,
                        label: 'Password Baru',
                        hint: 'Minimal 6 karakter',
                        obscureText: _obscureNewPassword,
                        onToggleObscure: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                      ),
                      const SizedBox(height: 12),
                      _buildPasswordField(
                        controller: _confirmPasswordCtrl,
                        label: 'Ulangi Password Baru',
                        hint: 'Ketik ulang password baru',
                        obscureText: _obscureConfirmPassword,
                        onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0891B2),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: _isChangingPassword
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(_isChangingPassword ? 'Memperbarui Password...' : 'Simpan Password Baru'),
                          onPressed: _isChangingPassword || currentUser == null
                              ? null
                              : () => _handleChangePassword(currentUser.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Khusus Super Admin: Pengaturan Integrasi & Cadangan
              if (isSuperAdmin) ...[
                // Super Admin Integration Settings Card
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
                                color: const Color(0xFFECFEFF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.admin_panel_settings, color: Color(0xFF0891B2), size: 20),
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

                        // Section: WhatsApp
                        const Text('1. WhatsApp Gateway (Fonnte)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Digunakan untuk mengirim kode OTP pendaftaran pelanggan via WhatsApp.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(height: 10),
                        _buildConfigField(
                          controller: _fonnteTokenCtrl,
                          label: 'Fonnte Device Token',
                          hint: 'Contoh: oNFkn2DLqbqtGUV5TajtLaJK',
                          isPassword: true,
                          obscure: _obscureFonnte,
                          onToggleObscure: () => setState(() => _obscureFonnte = !_obscureFonnte),
                        ),
                        _buildConfigField(
                          controller: _fonnteUrlCtrl,
                          label: 'Fonnte API URL',
                          hint: 'https://api.fonnte.com/send',
                        ),
                        const Divider(height: 24),

                        // Section: Email
                        const Text('2. Email Gateway (Gmail SMTP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Digunakan untuk mengirim kode OTP pendaftaran pelanggan via Email.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildConfigField(
                                controller: _mailHostCtrl,
                                label: 'SMTP Host',
                                hint: 'smtp.gmail.com',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildConfigField(
                                controller: _mailPortCtrl,
                                label: 'Port',
                                hint: '587',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        _buildConfigField(
                          controller: _mailUsernameCtrl,
                          label: 'Email Username (Gmail)',
                          hint: 'apoteksantosa@gmail.com',
                        ),
                        _buildConfigField(
                          controller: _mailPasswordCtrl,
                          label: 'App Password Gmail (16 Karakter)',
                          hint: 'xxxx xxxx xxxx xxxx',
                          isPassword: true,
                          obscure: _obscureMailPass,
                          onToggleObscure: () => setState(() => _obscureMailPass = !_obscureMailPass),
                        ),
                        _buildConfigField(
                          controller: _mailFromNameCtrl,
                          label: 'Nama Pengirim Email',
                          hint: 'Apotek Santosa Farma',
                        ),
                        const Divider(height: 24),

                        // Section: Midtrans
                        const Text('3. Midtrans Payment Gateway (QRIS & Online)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Kredensial Midtrans untuk pembayaran QRIS kasir dan Snap payment web.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(height: 10),
                        _buildConfigField(
                          controller: _midtransClientKeyCtrl,
                          label: 'Midtrans Client Key',
                          hint: 'Mid-client-... atau SB-Mid-client-...',
                        ),
                        _buildConfigField(
                          controller: _midtransServerKeyCtrl,
                          label: 'Midtrans Server Key',
                          hint: 'Mid-server-... atau SB-Mid-server-...',
                          isPassword: true,
                          obscure: _obscureMidtrans,
                          onToggleObscure: () => setState(() => _obscureMidtrans = !_obscureMidtrans),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mode Lingkungan (Environment)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                            _midtransIsProduction ? 'Transaksi menggunakan uang asli (Production)' : 'Transaksi menggunakan simulasi Sandbox',
                            style: TextStyle(fontSize: 11, color: _midtransIsProduction ? Colors.red : const Color(0xFF2563EB)),
                          ),
                          value: _midtransIsProduction,
                          activeColor: const Color(0xFF0891B2),
                          onChanged: (val) => setState(() => _midtransIsProduction = val),
                        ),
                        const SizedBox(height: 8),

                        // Test Connection Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: _isTestingMidtrans
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.network_check, size: 16),
                            label: Text(_isTestingMidtrans ? 'Memverifikasi...' : 'Uji Kredensial Midtrans'),
                            onPressed: _isTestingMidtrans ? null : _handleTestMidtrans,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0891B2),
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

                // Data Management (Backup, Restore, Reset) - Khusus Super Admin
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 16 : 20),
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
                        _buildDataActionTile(
                          isCompact: isCompact,
                          icon: Icons.cloud_upload_outlined,
                          iconColor: const Color(0xFF0891B2),
                          iconBg: const Color(0xFFECFEFF),
                          title: 'Cadangkan Database (ZIP / Drive)',
                          subtitle: 'Export seluruh data ke file ZIP dan bagikan ke Drive atau WhatsApp',
                          actionButton: FilledButton.icon(
                            icon: _isBackingUp
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.download, size: 16),
                            label: const Text('Backup'),
                            onPressed: _isBackingUp ? null : _handleBackup,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDataActionTile(
                          isCompact: isCompact,
                          icon: Icons.settings_backup_restore,
                          iconColor: const Color(0xFF2563EB),
                          iconBg: const Color(0xFFEFF6FF),
                          title: 'Pulihkan Data dari Backup',
                          subtitle: 'Pilih file ZIP atau JSON backup yang pernah Anda simpan',
                          actionButton: OutlinedButton.icon(
                            icon: _isRestoring
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.folder_open, size: 16),
                            label: const Text('Restore'),
                            onPressed: _isRestoring ? null : _handleRestore,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDataActionTile(
                          isCompact: isCompact,
                          icon: Icons.cleaning_services,
                          iconColor: const Color(0xFF0891B2),
                          iconBg: const Color(0xFFECFEFF),
                          title: 'Pindai & Bersihkan Storage Gambar',
                          subtitle: 'Hapus file foto lama di storage Supabase yang tidak terhubung dengan obat apapun',
                          actionButton: OutlinedButton.icon(
                            icon: _isCleaningStorage
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.cleaning_services, size: 16),
                            label: const Text('Bersihkan'),
                            onPressed: _isCleaningStorage ? null : _handleCleanStorage,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDataActionTile(
                          isCompact: isCompact,
                          icon: Icons.delete_forever,
                          iconColor: Colors.red,
                          iconBg: const Color(0xFFFEF2F2),
                          title: 'Reset Pabrik (Factory Reset)',
                          titleColor: Colors.red,
                          subtitle: 'Hapus seluruh transaksi dan kembalikan stok obat ke data awal',
                          actionButton: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: _isResetting ? null : _handleFactoryReset,
                            child: _isResetting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Reset'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),

              // App Version Info
              const Center(
                child: Column(
                  children: [
                    Text('Apotek Santosa Farma POS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    SizedBox(height: 2),
                    Text('Versi 1.0.0', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
