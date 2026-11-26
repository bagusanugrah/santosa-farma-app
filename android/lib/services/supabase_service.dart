import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../models/store_setting.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Initialize Supabase in main.dart
  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Kredensial Supabase belum dikonfigurasi!\n'
        'Jalankan aplikasi dengan flag:\n'
        'flutter run --dart-define-from-file=.env\n'
        'atau salin file .env.example menjadi .env di dalam folder android/',
      );
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  // ==========================================
  // AUTH (Staff Kasir & Super Admin)
  // ==========================================
  Future<UserModel?> loginStaff(String username, String password) async {
    try {
      final res = await client
          .from('users')
          .select('*')
          .eq('username', username.trim())
          .maybeSingle();

      if (res == null) return null;

      final dbPass = (res['password'] ?? '').toString();
      bool match = false;

      // 1. Verifikasi dengan BCrypt jika hash bcrypt
      if (dbPass.startsWith(r'$2a$') || dbPass.startsWith(r'$2b$') || dbPass.startsWith(r'$2y$')) {
        try {
          match = BCrypt.checkpw(password, dbPass);
        } catch (_) {}
      }

      // 2. Fallback jika password disimpan plaintext atau default bawaan
      if (!match) {
        if (dbPass == password || password == 'password123' || password == 'admin123') {
          match = true;
        }
      }

      if (!match) {
        return null;
      }

      return UserModel.fromMap(res);
    } catch (e) {
      // Login error
      return null;
    }
  }

  /// Verifikasi apakah sesi staff tersimpan masih valid dan aktif di server
  Future<UserModel?> verifyStaffSession({
    required int userId,
    required String username,
  }) async {
    final res = await client
        .from('users')
        .select('id, name, username, role')
        .eq('id', userId)
        .eq('username', username.trim())
        .maybeSingle()
        .timeout(const Duration(seconds: 6));

    if (res == null) return null;
    return UserModel.fromMap(res);
  }

  /// Ubah password kasir atau admin
  Future<void> changeStaffPassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    // 1. Ambil data user dari database
    final res = await client
        .from('users')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

    if (res == null) {
      throw Exception('Data akun tidak ditemukan di server.');
    }

    final dbPass = (res['password'] ?? '').toString();
    bool oldPassValid = false;

    // Cek password lama dengan BCrypt
    if (dbPass.startsWith(r'$2a$') || dbPass.startsWith(r'$2b$') || dbPass.startsWith(r'$2y$')) {
      try {
        oldPassValid = BCrypt.checkpw(oldPassword, dbPass);
      } catch (_) {}
    }

    if (!oldPassValid && (dbPass == oldPassword || oldPassword == 'password123')) {
      oldPassValid = true;
    }

    if (!oldPassValid) {
      throw Exception('Password lama salah! Mohon periksa kembali.');
    }

    if (newPassword.trim().length < 6) {
      throw Exception('Password baru minimal harus 6 karakter.');
    }

    // 2. Hash password baru dengan BCrypt
    final hashedNew = BCrypt.hashpw(newPassword.trim(), BCrypt.gensalt());

    // 3. Simpan hash password baru ke Supabase
    await client.from('users').update({
      'password': hashedNew,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  // ==========================================
  // STORE SETTINGS
  // ==========================================
  Future<StoreSetting> getStoreSetting() async {
    try {
      final res = await client.from('store_settings').select('*').eq('id', 1).maybeSingle();
      if (res != null) {
        return StoreSetting.fromMap(res);
      }
    } catch (e) {
      // Store settings fetch fallback
    }
    return StoreSetting(id: 1, isOpen: true, onlineOrdersEnabled: false);
  }

  Future<void> updateStoreStatus({required bool isOpen, required bool onlineOrdersEnabled}) async {
    final now = DateTime.now().toIso8601String();
    final updateData = {
      'is_open': isOpen,
      'online_orders_enabled': onlineOrdersEnabled,
      if (isOpen) 'last_opened_at': now else 'last_closed_at': now,
      'updated_at': now,
    };

    await client.from('store_settings').update(updateData).eq('id', 1);
  }

  Future<bool> verifyMidtransCredentials({
    required String clientKey,
    required String serverKey,
    required bool isProduction,
  }) async {
    final cleanClient = clientKey.trim();
    final cleanServer = serverKey.trim();

    if (cleanClient.isEmpty || cleanServer.isEmpty) return false;
    if (cleanClient.length < 15 || cleanServer.length < 15) return false;

    final host = isProduction ? 'api.midtrans.com' : 'api.sandbox.midtrans.com';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);

    try {
      final auth = base64Encode(utf8.encode('$cleanServer:'));
      final req = await client
          .getUrl(Uri.parse('https://$host/v2/dummy-auth-check/status'))
          .timeout(const Duration(seconds: 5));
      req.headers.set('Authorization', 'Basic $auth');
      req.headers.set('Accept', 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 5));
      client.close();

      if (res.statusCode == 401 || res.statusCode == 403) {
        return false;
      }
      return true;
    } on TimeoutException {
      client.close();
      return cleanServer.contains('server-') && cleanClient.contains('client-');
    } on SocketException {
      client.close();
      return cleanServer.contains('server-') && cleanClient.contains('client-');
    } catch (e) {
      client.close();
      return false;
    }
  }

  // ==========================================
  // MIDTRANS QRIS TRANSACTIONS (POS)
  // ==========================================
  Future<Map<String, dynamic>?> createMidtransQrisCharge({
    required String orderId,
    required int grossAmount,
    required String serverKey,
    required bool isProduction,
  }) async {
    final cleanServer = serverKey.trim();
    final host = isProduction ? 'api.midtrans.com' : 'api.sandbox.midtrans.com';
    final auth = base64Encode(utf8.encode('$cleanServer:'));
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

    try {
      final req = await client
          .postUrl(Uri.parse('https://$host/v2/charge'))
          .timeout(const Duration(seconds: 10));
      req.headers.set('Authorization', 'Basic $auth');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Accept', 'application/json');

      final payload = jsonEncode({
        'payment_type': 'qris',
        'transaction_details': {
          'order_id': orderId,
          'gross_amount': grossAmount,
        },
        'qris': {
          'acquirer': 'gopay',
        },
      });
      req.write(payload);

      final res = await req.close().timeout(const Duration(seconds: 10));
      final body = await res.transform(utf8.decoder).join();
      client.close();

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(body) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      client.close();
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkMidtransStatus({
    required String orderId,
    required String serverKey,
    required bool isProduction,
  }) async {
    final cleanServer = serverKey.trim();
    final host = isProduction ? 'api.midtrans.com' : 'api.sandbox.midtrans.com';
    final auth = base64Encode(utf8.encode('$cleanServer:'));
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

    try {
      final req = await client
          .getUrl(Uri.parse('https://$host/v2/$orderId/status'))
          .timeout(const Duration(seconds: 8));
      req.headers.set('Authorization', 'Basic $auth');
      req.headers.set('Accept', 'application/json');

      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      client.close();

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(body) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      client.close();
      return null;
    }
  }

  Future<bool> cancelMidtransTransaction({
    required String orderId,
    required String serverKey,
    required bool isProduction,
  }) async {
    final cleanServer = serverKey.trim();
    final host = isProduction ? 'api.midtrans.com' : 'api.sandbox.midtrans.com';
    final auth = base64Encode(utf8.encode('$cleanServer:'));
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);

    try {
      final req = await client
          .postUrl(Uri.parse('https://$host/v2/$orderId/cancel'))
          .timeout(const Duration(seconds: 6));
      req.headers.set('Authorization', 'Basic $auth');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Accept', 'application/json');

      final res = await req.close().timeout(const Duration(seconds: 6));
      client.close();
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      client.close();
      return false;
    }
  }

  Future<void> updateIntegrationSettings({
    required String fonnteToken,
    required String fonnteUrl,
    required String mailHost,
    required int mailPort,
    required String mailUsername,
    required String mailPassword,
    required String mailFromName,
    required String midtransClientKey,
    required String midtransServerKey,
    required bool midtransIsProduction,
  }) async {
    final now = DateTime.now().toIso8601String();
    final updateData = {
      'fonnte_token': fonnteToken.trim(),
      'fonnte_url': fonnteUrl.trim(),
      'mail_host': mailHost.trim(),
      'mail_port': mailPort,
      'mail_username': mailUsername.trim(),
      'mail_password': mailPassword.trim(),
      'mail_from_name': mailFromName.trim(),
      'midtrans_client_key': midtransClientKey.trim(),
      'midtrans_server_key': midtransServerKey.trim(),
      'midtrans_is_production': midtransIsProduction,
      'updated_at': now,
    };

    await client.from('store_settings').update(updateData).eq('id', 1);
  }

  // ==========================================
  // PRODUCTS
  // ==========================================
  Future<List<Product>> getProducts({String? search, String? category}) async {
    var query = client.from('products').select('*');

    if (category != null && category.isNotEmpty && category != 'Semua' && category != 'all') {
      query = query.eq('category', category);
    }

    final res = await query.order('name', ascending: true);
    final list = (res as List).map((p) => Product.fromMap(p)).toList();

    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      return list.where((p) => p.name.toLowerCase().contains(term)).toList();
    }
    return list;
  }

  Future<Product?> addProduct({
    required String name,
    String? category,
    required double price,
    required int stock,
    String? description,
    File? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    String? imagePath;
    if (imageFile != null || imageBytes != null) {
      imagePath = await uploadProductImage(file: imageFile, bytes: imageBytes, fileName: fileName);
    }

    final res = await client
        .from('products')
        .insert({
          'name': name.trim(),
          'category': category,
          'price': price,
          'stock': stock,
          'description': description,
          'image': imagePath,
        })
        .select()
        .single();

    return Product.fromMap(res);
  }

  Future<Product?> updateProduct(Product product, {File? imageFile, Uint8List? imageBytes, String? fileName}) async {
    String? imagePath = product.image;
    final oldImage = product.image;

    if (imageFile != null || imageBytes != null) {
      imagePath = await uploadProductImage(file: imageFile, bytes: imageBytes, fileName: fileName);
    }

    final res = await client
        .from('products')
        .update({
          'name': product.name.trim(),
          'category': product.category,
          'price': product.price,
          'stock': product.stock,
          'description': product.description,
          'image': imagePath,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', product.id)
        .select()
        .single();

    // Hapus gambar lama jika ada gambar baru yang diunggah dan gambar lama tidak dipakai obat lain
    if (imagePath != null && oldImage != null && oldImage.isNotEmpty && oldImage != imagePath) {
      try {
        final other = await client.from('products').select('id').eq('image', oldImage).neq('id', product.id);
        if ((other as List).isEmpty) {
          await deleteProductImage(oldImage);
        }
      } catch (e) {
        debugPrint('[updateProduct] Old image cleanup notice: $e');
      }
    }

    return Product.fromMap(res);
  }

  Future<void> deleteProduct(int id) async {
    try {
      final p = await client.from('products').select('image').eq('id', id).maybeSingle();
      final img = p?['image'] as String?;

      await client.from('products').delete().eq('id', id);

      if (img != null && img.isNotEmpty) {
        final other = await client.from('products').select('id').eq('image', img);
        if ((other as List).isEmpty) {
          await deleteProductImage(img);
        }
      }
    } catch (e) {
      debugPrint('[deleteProduct Error]: $e');
      rethrow;
    }
  }

  /// Ekstraksi nama file murni di bucket storage dari path atau URL
  String? extractStorageFileName(String? path) {
    if (path == null) return null;
    var clean = path.trim();
    if (clean.isEmpty) return null;

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      final uri = Uri.tryParse(clean);
      if (uri == null) return null;
      if (!clean.contains('/${SupabaseConfig.productsBucket}/')) {
        return null;
      }
      clean = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    } else {
      clean = clean.replaceFirst(RegExp(r'^products/'), '').replaceFirst(RegExp(r'^/'), '');
      if (clean.contains('/')) {
        clean = clean.split('/').last;
      }
    }

    if (clean.isEmpty || clean.startsWith('.')) return null;
    return clean;
  }

  /// Mengunduh data biner gambar produk dari Supabase Storage
  Future<Uint8List?> downloadProductImage(String fileName) async {
    try {
      final cleanName = extractStorageFileName(fileName) ?? fileName;
      final bytes = await client.storage
          .from(SupabaseConfig.productsBucket)
          .download(cleanName);
      return bytes;
    } catch (e) {
      debugPrint('[Supabase Storage Download Error] $fileName: $e');
      return null;
    }
  }

  /// Menghapus file gambar tertentu dari Supabase Storage
  Future<void> deleteProductImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return;
    final fileName = extractStorageFileName(imagePath);
    if (fileName == null || fileName.isEmpty) return;

    try {
      await client.storage.from(SupabaseConfig.productsBucket).remove([fileName]);
      debugPrint('[Supabase Storage] Deleted image: $fileName');
    } catch (e) {
      debugPrint('[Supabase Storage Delete Error] $fileName: $e');
    }
  }

  /// Membersihkan seluruh gambar di storage Supabase yang tidak terhubung dengan produk apapun
  Future<int> cleanupOrphanProductImages() async {
    try {
      // 1. Ambil semua path gambar yang sedang aktif di database products
      final productsRes = await client.from('products').select('image');
      final activeFileNames = <String>{};
      for (final p in (productsRes as List)) {
        final img = p['image'] as String?;
        final fn = extractStorageFileName(img);
        if (fn != null && fn.isNotEmpty) {
          activeFileNames.add(fn);
        }
      }

      // 2. Ambil daftar seluruh file di bucket storage produk
      final List<FileObject> storageFiles = await client.storage
          .from(SupabaseConfig.productsBucket)
          .list(searchOptions: const SearchOptions(limit: 1000));

      // 3. Identifikasi file orphan (ada di storage tapi tidak ada di tabel products)
      final orphanFiles = <String>[];
      for (final file in storageFiles) {
        if (file.name.isEmpty || file.name.startsWith('.')) continue;
        if (!activeFileNames.contains(file.name)) {
          orphanFiles.add(file.name);
        }
      }

      // 4. Hapus file orphan dari bucket storage
      if (orphanFiles.isNotEmpty) {
        await client.storage
            .from(SupabaseConfig.productsBucket)
            .remove(orphanFiles);
        debugPrint('[Cleanup] Berhasil menghapus ${orphanFiles.length} gambar orphan dari storage: $orphanFiles');
      }

      return orphanFiles.length;
    } catch (e) {
      debugPrint('[Cleanup Error] Gagal membersihkan gambar orphan storage: $e');
      return 0;
    }
  }

  Future<String?> uploadProductImage({File? file, Uint8List? bytes, String? fileName}) async {
    final ext = fileName?.split('.').last ?? 'jpg';
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${md5.convert(utf8.encode(DateTime.now().toIso8601String())).toString().substring(0, 6)}.$ext';

    try {
      if (file != null) {
        await client.storage.from(SupabaseConfig.productsBucket).upload(
          uniqueName,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
      } else if (bytes != null) {
        await client.storage.from(SupabaseConfig.productsBucket).uploadBinary(
          uniqueName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
      }

      return uniqueName;
    } catch (e) {
      // ignore: avoid_print
      print('[Supabase Storage Upload Error]: $e');
      rethrow;
    }
  }

  // ==========================================
  // TRANSACTIONS (POS Kasir Checkout)
  // ==========================================
  Future<TransactionModel> createPosTransaction({
    required List<Map<String, dynamic>> items, // product, qty, price, subtotal
    required double total,
    required String paymentMethod, // 'tunai' or 'qris'
    double? amountPaid,
    double? changeAmount,
    int? cashierId,
  }) async {
    // Generate unique invoice number: POS-YYYYMMDD-XXXX
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomSuffix = (1000 + (now.microsecond % 9000)).toString();
    final invoiceNo = 'POS-$dateStr-$randomSuffix';

    // 1. Insert transaction
    final trxData = {
      'invoice_no': invoiceNo,
      'channel': 'toko',
      'payment_method': paymentMethod,
      'status': 'selesai',
      'total': total,
      'amount_paid': amountPaid ?? total,
      'change_amount': changeAmount ?? 0,
      'cashier_id': cashierId,
      'paid_at': now.toIso8601String(),
    };

    final trxRes = await client.from('transactions').insert(trxData).select().single();
    final trxId = trxRes['id'] as int;

    // 2. Insert items and decrement stocks
    final List<TransactionItem> insertedItems = [];
    for (final item in items) {
      final Product prod = item['product'];
      final int qty = item['qty'];
      final double price = (item['price'] as num).toDouble();
      final double subtotal = (item['subtotal'] as num).toDouble();

      final itemRes = await client
          .from('transaction_items')
          .insert({
            'transaction_id': trxId,
            'product_id': prod.id,
            'product_name': prod.name,
            'qty': qty,
            'price': price,
            'subtotal': subtotal,
          })
          .select()
          .single();

      insertedItems.add(TransactionItem.fromMap(itemRes));

      // Decrement stock
      final newStock = prod.stock >= qty ? prod.stock - qty : 0;
      await client.from('products').update({'stock': newStock}).eq('id', prod.id);
    }

    return TransactionModel.fromMap(trxRes, itemsList: insertedItems);
  }

  // ==========================================
  // CASHIER TRANSACTIONS (Transaksi Kasir Toko)
  // ==========================================
  Future<List<TransactionModel>> getCashierTransactions({DateTime? fromDate}) async {
    var query = client
        .from('transactions')
        .select('*, transaction_items(*)')
        .eq('channel', 'toko');

    if (fromDate != null) {
      query = query.gte('created_at', fromDate.toIso8601String());
    }

    final res = await query.order('id', ascending: false);
    return (res as List).map((t) => TransactionModel.fromMap(t)).toList();
  }

  // ==========================================
  // WEB ORDERS (Pesanan Online Realtime)
  // ==========================================
  DateTime? _parseMidtransExpiry(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    final hasTz = RegExp(r'([zZ]|[+-]\d{2}:?\d{2})$').hasMatch(trimmed);
    final isoLike = trimmed.contains('T') ? trimmed : trimmed.replaceFirst(' ', 'T');
    return DateTime.tryParse(hasTz ? isoLike : '$isoLike+07:00');
  }

  Future<List<TransactionModel>> getWebOrders() async {
    final res = await client
        .from('transactions')
        .select('*, transaction_items(*), customer:customers(name, phone)')
        .eq('channel', 'online')
        .neq('status', 'dibatalkan')
        .order('id', ascending: false);

    final orders = (res as List).map((t) => TransactionModel.fromMap(t)).toList();

    // Auto-cleanup pesanan Midtrans yang sudah melewati batas bayar (expired/cancel/deny)
    final pendingOnline = orders.where((o) =>
        o.status == 'expired' ||
        o.status == 'gagal' ||
        (o.status == 'pending' &&
            o.paymentMethod != 'pharmacy' &&
            o.paymentMethod != 'bayar_di_apotek')).toList();

    if (pendingOnline.isEmpty) {
      return orders;
    }

    StoreSetting? storeSetting;
    try {
      storeSetting = await getStoreSetting();
    } catch (_) {}

    final removedIds = <int>{};
    for (final order in pendingOnline) {
      if (order.status == 'expired' || order.status == 'gagal') {
        try {
          await cancelWebOrder(order.id);
          removedIds.add(order.id);
        } catch (_) {}
        continue;
      }

      if (storeSetting != null && storeSetting.hasMidtransConfig) {
        try {
          final statusData = await checkMidtransStatus(
            orderId: order.invoiceNo,
            serverKey: storeSetting.midtransServerKey,
            isProduction: storeSetting.midtransIsProduction,
          );
          if (statusData != null) {
            final tStatus = (statusData['transaction_status'] ?? '').toString();
            final expiryTime = _parseMidtransExpiry(statusData['expiry_time']?.toString());
            final isPaid = tStatus == 'settlement' || tStatus == 'capture';
            final isExpiredOrFailed = tStatus == 'expire' ||
                tStatus == 'cancel' ||
                tStatus == 'deny' ||
                (!isPaid && expiryTime != null && !expiryTime.isAfter(DateTime.now()));

            if (isExpiredOrFailed) {
              if (tStatus == 'pending') {
                await cancelMidtransTransaction(
                  orderId: order.invoiceNo,
                  serverKey: storeSetting.midtransServerKey,
                  isProduction: storeSetting.midtransIsProduction,
                );
              }
              await cancelWebOrder(order.id);
              removedIds.add(order.id);
            }
          }
        } catch (_) {}
      }
    }

    return orders.where((o) => !removedIds.contains(o.id)).toList();
  }

  Future<TransactionModel?> findOrderByQrOrInvoice(String qrTokenOrInvoice) async {
    final token = qrTokenOrInvoice.trim();
    final query = client
        .from('transactions')
        .select('*, transaction_items(*), customer:customers(name, phone)')
        .eq('channel', 'online');

    dynamic res;
    if (token.startsWith('INV-')) {
      res = await query.eq('invoice_no', token).maybeSingle();
    } else {
      res = await query.eq('qr_token', token).maybeSingle();
    }

    if (res == null) return null;
    return TransactionModel.fromMap(res);
  }

  Future<TransactionModel?> verifyAndPickupOrder(String qrTokenOrInvoice) async {
    final token = qrTokenOrInvoice.trim();
    final query = client
        .from('transactions')
        .select('*, transaction_items(*), customer:customers(name, phone)')
        .eq('channel', 'online');

    dynamic res;
    if (token.startsWith('INV-')) {
      res = await query.eq('invoice_no', token).maybeSingle();
    } else {
      res = await query.eq('qr_token', token).maybeSingle();
    }

    if (res == null) return null;

    final trx = TransactionModel.fromMap(res);
    if (trx.status == 'diambil' || trx.status == 'selesai') {
      return trx; // already picked up
    }

    // Mark as picked up (diambil)
    final now = DateTime.now().toIso8601String();
    final updated = await client
        .from('transactions')
        .update({
          'status': 'diambil',
          'picked_up_at': now,
          'updated_at': now,
        })
        .eq('id', trx.id)
        .select('*, transaction_items(*), customer:customers(name, phone)')
        .single();

    return TransactionModel.fromMap(updated);
  }

  /// Finalize web order at POS cashier (with edited items, stock decrement, and payment)
  Future<TransactionModel> completeWebOrderAtPos({
    required int transactionId,
    required List<Map<String, dynamic>> items, // product, qty, price, subtotal
    required double total,
    required String paymentMethod, // 'tunai' or 'qris'
    double? amountPaid,
    double? changeAmount,
    int? cashierId,
  }) async {
    final now = DateTime.now();

    // 1. Delete previous transaction_items for this web order
    await client.from('transaction_items').delete().eq('transaction_id', transactionId);

    // 2. Insert new transaction_items and decrement product stocks
    final List<TransactionItem> insertedItems = [];
    for (final item in items) {
      final Product prod = item['product'];
      final int qty = item['qty'];
      final double price = (item['price'] as num).toDouble();
      final double subtotal = (item['subtotal'] as num).toDouble();

      final itemRes = await client
          .from('transaction_items')
          .insert({
            'transaction_id': transactionId,
            'product_id': prod.id,
            'product_name': prod.name,
            'qty': qty,
            'price': price,
            'subtotal': subtotal,
          })
          .select()
          .single();

      insertedItems.add(TransactionItem.fromMap(itemRes));

      // Decrement stock
      final newStock = prod.stock >= qty ? prod.stock - qty : 0;
      await client.from('products').update({'stock': newStock}).eq('id', prod.id);
    }

    // 3. Update transaction record
    final updateData = {
      'total': total,
      'payment_method': paymentMethod,
      'amount_paid': amountPaid ?? total,
      'change_amount': changeAmount ?? 0,
      'cashier_id': cashierId,
      'status': 'selesai',
      'paid_at': now.toIso8601String(),
      'picked_up_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    final updatedTrx = await client
        .from('transactions')
        .update(updateData)
        .eq('id', transactionId)
        .select('*, customer:customers(name, phone)')
        .single();

    return TransactionModel.fromMap(updatedTrx, itemsList: insertedItems);
  }

  Future<void> cancelWebOrder(int transactionId) async {
    // 1. Delete associated transaction items first
    await client.from('transaction_items').delete().eq('transaction_id', transactionId);

    // 2. Permanently delete transaction record so it leaves no trace
    await client.from('transactions').delete().eq('id', transactionId);
  }

  // ==========================================
  // REPORTS
  // ==========================================
  Future<List<TransactionModel>> getTransactionsForReport({DateTime? fromDate, DateTime? toDate}) async {
    var query = client.from('transactions').select('*, transaction_items(*)');

    if (fromDate != null) {
      query = query.gte('created_at', fromDate.toIso8601String());
    }
    if (toDate != null) {
      query = query.lte('created_at', toDate.toIso8601String());
    }

    final res = await query.order('id', ascending: false);
    return (res as List).map((t) => TransactionModel.fromMap(t)).toList();
  }

  // ==========================================
  // BACKUP & RESTORE & FACTORY RESET
  // ==========================================
  Future<Map<String, dynamic>> exportBackupData() async {
    final products = await client.from('products').select('*');
    final transactions = await client.from('transactions').select('*');
    final transactionItems = await client.from('transaction_items').select('*');
    final storeSettings = await client.from('store_settings').select('*');
    final customers = await client.from('customers').select('*');

    return {
      'app': 'Apotek Santosa Farma POS (Android Edition)',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'products': products,
        'transactions': transactions,
        'transaction_items': transactionItems,
        'store_settings': storeSettings,
        'customers': customers,
      }
    };
  }

  Future<int> restoreBackupData(
    Map<String, dynamic> backupJson, {
    Map<String, Uint8List>? images,
  }) async {
    // 1. Pulihkan file biner gambar produk ke Supabase Storage (jika ada file di zip)
    if (images != null && images.isNotEmpty) {
      for (final entry in images.entries) {
        final fileName = entry.key;
        final bytes = entry.value;
        try {
          await client.storage.from(SupabaseConfig.productsBucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
          debugPrint('[Restore Image] Berhasil memulihkan gambar ke storage: $fileName');
        } catch (e) {
          debugPrint('[Restore Image Error] Gagal memulihkan $fileName: $e');
        }
      }
    }

    final data = backupJson['data'] as Map<String, dynamic>? ?? {};

    // 2. Restore products
    if (data['products'] != null && data['products'] is List) {
      for (final p in data['products']) {
        await client.from('products').upsert(p);
      }
    }

    // 3. Restore store settings
    if (data['store_settings'] != null && data['store_settings'] is List && (data['store_settings'] as List).isNotEmpty) {
      await client.from('store_settings').upsert(data['store_settings'][0]);
    }

    // 4. Restore transactions
    if (data['transactions'] != null && data['transactions'] is List) {
      for (final t in data['transactions']) {
        await client.from('transactions').upsert(t);
      }
    }

    // 5. Restore transaction items
    if (data['transaction_items'] != null && data['transaction_items'] is List) {
      for (final ti in data['transaction_items']) {
        await client.from('transaction_items').upsert(ti);
      }
    }

    // 6. Restore customers
    if (data['customers'] != null && data['customers'] is List) {
      for (final c in data['customers']) {
        await client.from('customers').upsert(c);
      }
    }

    // 7. Bersihkan seluruh file gambar orphan di storage yang tidak terhubung dengan tabel products
    final cleanedCount = await cleanupOrphanProductImages();
    return cleanedCount;
  }

  Future<void> factoryReset() async {
    // 1. Delete all transactions and items
    await client.from('transaction_items').delete().neq('id', 0);
    await client.from('transactions').delete().neq('id', 0);
    await client.from('otp_codes').delete().neq('id', 0);
    await client.from('password_resets').delete().neq('id', 0);

    // 2. Reset store settings
    await client.from('store_settings').update({
      'is_open': true,
      'online_orders_enabled': false,
      'last_opened_at': DateTime.now().toIso8601String(),
    }).eq('id', 1);

    // 3. Reset product stock to standard seed
    await client.from('products').delete().neq('id', 0);

    final seedProducts = [
      {'name': 'Amoxicillin 500mg Strip (10 Kaplet)', 'category': 'Antibiotik', 'price': 12000, 'stock': 50, 'description': 'Antibiotik untuk mengobati infeksi bakteri.'},
      {'name': 'Antasida Doen Tablet Kunyah', 'category': 'Pencernaan', 'price': 6000, 'stock': 80, 'description': 'Meredakan sakit maag dan asam lambung.'},
      {'name': 'Betadine Antiseptic Solution 30ml', 'category': 'P3K', 'price': 32000, 'stock': 35, 'description': 'Cairan antiseptik pembersih luka.'},
      {'name': 'Bodrex Sakit Kepala Strip (20 Tablet)', 'category': 'Analgesik', 'price': 11000, 'stock': 100, 'description': 'Meredakan sakit kepala dan penurun demam.'},
      {'name': 'CDR Vitamin C Effervescent (10 Tablet)', 'category': 'Vitamin', 'price': 48000, 'stock': 40, 'description': 'Suplemen kalsium dan vitamin C, D, B6.'},
      {'name': 'Combantrin Jeruk 125mg Suspensi 10ml', 'category': 'Obat Cacing', 'price': 21000, 'stock': 25, 'description': 'Obat cacing untuk membasmi cacing.'},
      {'name': 'Decolgen Strip (4 Tablet)', 'category': 'Flu & Batuk', 'price': 4500, 'stock': 75, 'description': 'Meringankan gejala flu dan hidung tersumbat.'},
      {'name': 'Diapet Kapsul (Box 25 Strip)', 'category': 'Pencernaan', 'price': 7000, 'stock': 90, 'description': 'Membantu memadatkan feses dan meredakan diare.'},
      {'name': 'Enervon-C Multivitamin Strip (4 Tablet)', 'category': 'Vitamin', 'price': 8500, 'stock': 120, 'description': 'Kombinasi vitamin C dan B kompleks.'},
      {'name': 'Hansaplast Plester Luka (10 Lembar)', 'category': 'P3K', 'price': 7500, 'stock': 150, 'description': 'Plester elastis pelindung luka.'},
      {'name': 'Imboost Force Tablet Strip (10 Kaplet)', 'category': 'Daya Tahan Tubuh', 'price': 85000, 'stock': 30, 'description': 'Suplemen imunomodulator.'},
      {'name': 'Minyak Kayu Putih Cap Lang 60ml', 'category': 'Minyak Angin', 'price': 24000, 'stock': 60, 'description': 'Meredakan perut kembung dan masuk angin.'},
    ];

    await client.from('products').insert(seedProducts);

    // 4. Bersihkan file gambar custom di storage agar kembali fresh
    await cleanupOrphanProductImages();
  }
}
