class StoreSetting {
  final int id;
  final bool isOpen;
  final bool onlineOrdersEnabled;
  final DateTime? lastOpenedAt;
  final DateTime? lastClosedAt;

  StoreSetting({
    required this.id,
    required this.isOpen,
    required this.onlineOrdersEnabled,
    this.lastOpenedAt,
    this.lastClosedAt,
  });

  bool get isOnlineActive => isOpen && onlineOrdersEnabled;

  factory StoreSetting.fromMap(Map<String, dynamic> map) {
    return StoreSetting(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      isOpen: map['is_open'] == true,
      onlineOrdersEnabled: map['online_orders_enabled'] == true,
      lastOpenedAt: map['last_opened_at'] != null ? DateTime.tryParse(map['last_opened_at']) : null,
      lastClosedAt: map['last_closed_at'] != null ? DateTime.tryParse(map['last_closed_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_open': isOpen,
      'online_orders_enabled': onlineOrdersEnabled,
      'last_opened_at': lastOpenedAt?.toIso8601String(),
      'last_closed_at': lastClosedAt?.toIso8601String(),
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

  bool get isSuperAdmin => role == 'super_admin';

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
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
