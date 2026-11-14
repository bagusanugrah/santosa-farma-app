class TransactionItem {
  final int id;
  final int transactionId;
  final int? productId;
  final String productName;
  final int qty;
  final double price;
  final double subtotal;

  TransactionItem({
    required this.id,
    required this.transactionId,
    this.productId,
    required this.productName,
    required this.qty,
    required this.price,
    required this.subtotal,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      transactionId: map['transaction_id'] is int
          ? map['transaction_id']
          : int.parse(map['transaction_id'].toString()),
      productId: map['product_id'] != null
          ? (map['product_id'] is int ? map['product_id'] : int.parse(map['product_id'].toString()))
          : null,
      productName: map['product_name'] ?? '',
      qty: map['qty'] is int ? map['qty'] : int.tryParse(map['qty']?.toString() ?? '1') ?? 1,
      price: (map['price'] is num)
          ? (map['price'] as num).toDouble()
          : double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      subtotal: (map['subtotal'] is num)
          ? (map['subtotal'] as num).toDouble()
          : double.tryParse(map['subtotal']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'qty': qty,
      'price': price,
      'subtotal': subtotal,
    };
  }
}
