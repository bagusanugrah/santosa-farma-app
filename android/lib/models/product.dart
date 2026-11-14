import '../config/supabase_config.dart';

class Product {
  final int id;
  final String name;
  final String? category;
  final double price;
  final int stock;
  final String? description;
  final String? image;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    this.category,
    required this.price,
    required this.stock,
    this.description,
    this.image,
    this.createdAt,
    this.updatedAt,
  });

  String get imageUrl => SupabaseConfig.getProductImageUrl(image);

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      name: map['name'] ?? '',
      category: map['category'],
      price: (map['price'] is num)
          ? (map['price'] as num).toDouble()
          : double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      stock: map['stock'] is int ? map['stock'] : int.tryParse(map['stock']?.toString() ?? '0') ?? 0,
      description: map['description'],
      image: map['image'],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'description': description,
      'image': image,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? price,
    int? stock,
    String? description,
    String? image,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      description: description ?? this.description,
      image: image ?? this.image,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
