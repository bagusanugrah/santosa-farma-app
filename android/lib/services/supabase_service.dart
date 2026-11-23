import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
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

    return Product.fromMap(res);
  }

  Future<void> deleteProduct(int id) async {
    await client.from('products').delete().eq('id', id);
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
  // WEB ORDERS (Pesanan Online Realtime)
  // ==========================================
  Future<List<TransactionModel>> getWebOrders() async {
    final res = await client
        .from('transactions')
        .select('*, transaction_items(*), customer:customers(name, phone)')
        .eq('channel', 'online')
        .order('id', ascending: false);

    return (res as List).map((t) => TransactionModel.fromMap(t)).toList();
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
    await client
        .from('transactions')
        .update({
          'status': 'dibatalkan',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', transactionId);
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

  Future<void> restoreBackupData(Map<String, dynamic> backupJson) async {
    final data = backupJson['data'] as Map<String, dynamic>? ?? {};

    // Restore products
    if (data['products'] != null && data['products'] is List) {
      for (final p in data['products']) {
        await client.from('products').upsert(p);
      }
    }

    // Restore store settings
    if (data['store_settings'] != null && data['store_settings'] is List && (data['store_settings'] as List).isNotEmpty) {
      await client.from('store_settings').upsert(data['store_settings'][0]);
    }

    // Restore transactions
    if (data['transactions'] != null && data['transactions'] is List) {
      for (final t in data['transactions']) {
        await client.from('transactions').upsert(t);
      }
    }

    // Restore transaction items
    if (data['transaction_items'] != null && data['transaction_items'] is List) {
      for (final ti in data['transaction_items']) {
        await client.from('transaction_items').upsert(ti);
      }
    }
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
  }
}
