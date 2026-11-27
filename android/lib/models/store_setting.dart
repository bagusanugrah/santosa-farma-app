class StoreSetting {
  final int id;
  final bool isOpen;
  final bool onlineOrdersEnabled;
  final DateTime? lastOpenedAt;
  final DateTime? lastClosedAt;

  // Profil & Kontak Apotek
  final String storeAddress;
  final String storePhone;

  // WhatsApp Fonnte Gateway
  final String fonnteToken;
  final String fonnteUrl;

  // Email SMTP (Gmail)
  final String mailHost;
  final int mailPort;
  final String mailUsername;
  final String mailPassword;
  final String mailFromName;

  // Midtrans Payment Gateway
  final String midtransClientKey;
  final String midtransServerKey;
  final bool midtransIsProduction;

  StoreSetting({
    required this.id,
    required this.isOpen,
    required this.onlineOrdersEnabled,
    this.lastOpenedAt,
    this.lastClosedAt,
    this.storeAddress = '',
    this.storePhone = '',
    this.fonnteToken = '',
    this.fonnteUrl = 'https://api.fonnte.com/send',
    this.mailHost = 'smtp.gmail.com',
    this.mailPort = 587,
    this.mailUsername = 'kucitcloud@gmail.com',
    this.mailPassword = '',
    this.mailFromName = 'Apotek Santosa Farma',
    this.midtransClientKey = '',
    this.midtransServerKey = '',
    this.midtransIsProduction = false,
  });

  bool get isOnlineActive => isOpen && onlineOrdersEnabled && hasMidtransConfig;

  bool get hasMidtransConfig =>
      midtransClientKey.trim().isNotEmpty && midtransServerKey.trim().isNotEmpty;

  factory StoreSetting.fromMap(Map<String, dynamic> map) {
    return StoreSetting(
      id: map['id'] is int ? map['id'] : (int.tryParse(map['id']?.toString() ?? '1') ?? 1),
      isOpen: map['is_open'] == true,
      onlineOrdersEnabled: map['online_orders_enabled'] == true,
      lastOpenedAt: map['last_opened_at'] != null ? DateTime.tryParse(map['last_opened_at'].toString())?.toLocal() : null,
      lastClosedAt: map['last_closed_at'] != null ? DateTime.tryParse(map['last_closed_at'].toString())?.toLocal() : null,
      storeAddress: map['store_address']?.toString() ?? '',
      storePhone: map['store_phone']?.toString() ?? '',
      fonnteToken: map['fonnte_token']?.toString() ?? '',
      fonnteUrl: map['fonnte_url']?.toString() ?? 'https://api.fonnte.com/send',
      mailHost: map['mail_host']?.toString() ?? 'smtp.gmail.com',
      mailPort: map['mail_port'] is int ? map['mail_port'] : int.tryParse(map['mail_port']?.toString() ?? '') ?? 587,
      mailUsername: map['mail_username']?.toString() ?? 'kucitcloud@gmail.com',
      mailPassword: map['mail_password']?.toString() ?? '',
      mailFromName: map['mail_from_name']?.toString() ?? 'Apotek Santosa Farma',
      midtransClientKey: map['midtrans_client_key']?.toString() ?? '',
      midtransServerKey: map['midtrans_server_key']?.toString() ?? '',
      midtransIsProduction: map['midtrans_is_production'] == true,
    );
  }

  StoreSetting copyWith({
    int? id,
    bool? isOpen,
    bool? onlineOrdersEnabled,
    DateTime? lastOpenedAt,
    DateTime? lastClosedAt,
    String? storeAddress,
    String? storePhone,
    String? fonnteToken,
    String? fonnteUrl,
    String? mailHost,
    int? mailPort,
    String? mailUsername,
    String? mailPassword,
    String? mailFromName,
    String? midtransClientKey,
    String? midtransServerKey,
    bool? midtransIsProduction,
  }) {
    return StoreSetting(
      id: id ?? this.id,
      isOpen: isOpen ?? this.isOpen,
      onlineOrdersEnabled: onlineOrdersEnabled ?? this.onlineOrdersEnabled,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastClosedAt: lastClosedAt ?? this.lastClosedAt,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      fonnteToken: fonnteToken ?? this.fonnteToken,
      fonnteUrl: fonnteUrl ?? this.fonnteUrl,
      mailHost: mailHost ?? this.mailHost,
      mailPort: mailPort ?? this.mailPort,
      mailUsername: mailUsername ?? this.mailUsername,
      mailPassword: mailPassword ?? this.mailPassword,
      mailFromName: mailFromName ?? this.mailFromName,
      midtransClientKey: midtransClientKey ?? this.midtransClientKey,
      midtransServerKey: midtransServerKey ?? this.midtransServerKey,
      midtransIsProduction: midtransIsProduction ?? this.midtransIsProduction,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_open': isOpen,
      'online_orders_enabled': onlineOrdersEnabled,
      'last_opened_at': lastOpenedAt?.toUtc().toIso8601String(),
      'last_closed_at': lastClosedAt?.toUtc().toIso8601String(),
      'store_address': storeAddress,
      'store_phone': storePhone,
      'fonnte_token': fonnteToken,
      'fonnte_url': fonnteUrl,
      'mail_host': mailHost,
      'mail_port': mailPort,
      'mail_username': mailUsername,
      'mail_password': mailPassword,
      'mail_from_name': mailFromName,
      'midtrans_client_key': midtransClientKey,
      'midtrans_server_key': midtransServerKey,
      'midtrans_is_production': midtransIsProduction,
    };
  }
}

class UserModel {
  final int id;
  final String name;
  final String username;
  final String role; // 'super_admin' or 'admin_kasir'

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
  });

  bool get isSuperAdmin => role == 'super_admin' || role == 'admin';

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] is int ? map['id'] : (int.tryParse(map['id']?.toString() ?? '0') ?? 0),
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      role: map['role'] ?? 'admin_kasir',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'role': role,
    };
  }
}
