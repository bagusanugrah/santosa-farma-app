import 'transaction_item.dart';

class TransactionModel {
  final int id;
  final String invoiceNo;
  final String channel; // 'toko' or 'online'
  final int? customerId;
  final int? cashierId;
  final String paymentMethod; // 'tunai', 'qris', 'kartu', 'va'
  final String? midtransOrderId;
  final String? midtransSnapToken;
  final String? midtransQrisUrl;
  final String? midtransVaNumber;
  final String status; // 'pending', 'paid', 'diambil', 'selesai', 'expired', 'gagal'
  final double total;
  final double? amountPaid;
  final double? changeAmount;
  final String? qrToken;
  final DateTime? paidAt;
  final DateTime? pickedUpAt;
  final DateTime createdAt;
  final List<TransactionItem> items;
  final String? customerName;
  final String? customerPhone;

  TransactionModel({
    required this.id,
    required this.invoiceNo,
    required this.channel,
    this.customerId,
    this.cashierId,
    required this.paymentMethod,
    this.midtransOrderId,
    this.midtransSnapToken,
    this.midtransQrisUrl,
    this.midtransVaNumber,
    required this.status,
    required this.total,
    this.amountPaid,
    this.changeAmount,
    this.qrToken,
    this.paidAt,
    this.pickedUpAt,
    required this.createdAt,
    this.items = const [],
    this.customerName,
    this.customerPhone,
  });

  bool get isOnline => channel == 'online';
  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';
  bool get isReadyForPickup => isOnline && status == 'paid';
  bool get isCompleted => status == 'selesai' || status == 'diambil';

  factory TransactionModel.fromMap(Map<String, dynamic> map, {List<TransactionItem>? itemsList}) {
    List<TransactionItem> parsedItems = itemsList ?? [];
    if (parsedItems.isEmpty && map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List)
          .map((i) => TransactionItem.fromMap(i as Map<String, dynamic>))
          .toList();
    } else if (parsedItems.isEmpty && map['transaction_items'] != null && map['transaction_items'] is List) {
      parsedItems = (map['transaction_items'] as List)
          .map((i) => TransactionItem.fromMap(i as Map<String, dynamic>))
          .toList();
    }

    String? custName;
    String? custPhone;
    if (map['customers'] != null && map['customers'] is Map) {
      custName = map['customers']['name'];
      custPhone = map['customers']['phone'];
    } else if (map['customer'] != null && map['customer'] is Map) {
      custName = map['customer']['name'];
      custPhone = map['customer']['phone'];
    }

    return TransactionModel(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      invoiceNo: map['invoice_no'] ?? '',
      channel: map['channel'] ?? 'toko',
      customerId: map['customer_id'] != null
          ? (map['customer_id'] is int ? map['customer_id'] : int.tryParse(map['customer_id'].toString()))
          : null,
      cashierId: map['cashier_id'] != null
          ? (map['cashier_id'] is int ? map['cashier_id'] : int.tryParse(map['cashier_id'].toString()))
          : null,
      paymentMethod: map['payment_method'] ?? 'tunai',
      midtransOrderId: map['midtrans_order_id'],
      midtransSnapToken: map['midtrans_snap_token'],
      midtransQrisUrl: map['midtrans_qris_url'],
      midtransVaNumber: map['midtrans_va_number'],
      status: map['status'] ?? 'pending',
      total: (map['total'] is num)
          ? (map['total'] as num).toDouble()
          : double.tryParse(map['total']?.toString() ?? '0') ?? 0.0,
      amountPaid: map['amount_paid'] != null
          ? ((map['amount_paid'] is num)
              ? (map['amount_paid'] as num).toDouble()
              : double.tryParse(map['amount_paid'].toString()))
          : null,
      changeAmount: map['change_amount'] != null
          ? ((map['change_amount'] is num)
              ? (map['change_amount'] as num).toDouble()
              : double.tryParse(map['change_amount'].toString()))
          : null,
      qrToken: map['qr_token'],
      paidAt: map['paid_at'] != null ? DateTime.tryParse(map['paid_at']) : null,
      pickedUpAt: map['picked_up_at'] != null ? DateTime.tryParse(map['picked_up_at']) : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
      items: parsedItems,
      customerName: custName,
      customerPhone: custPhone,
    );
  }

  TransactionModel copyWith({
    String? status,
    DateTime? paidAt,
    DateTime? pickedUpAt,
    List<TransactionItem>? items,
  }) {
    return TransactionModel(
      id: id,
      invoiceNo: invoiceNo,
      channel: channel,
      customerId: customerId,
      cashierId: cashierId,
      paymentMethod: paymentMethod,
      midtransOrderId: midtransOrderId,
      midtransSnapToken: midtransSnapToken,
      midtransQrisUrl: midtransQrisUrl,
      midtransVaNumber: midtransVaNumber,
      status: status ?? this.status,
      total: total,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
      qrToken: qrToken,
      paidAt: paidAt ?? this.paidAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      createdAt: createdAt,
      items: items ?? this.items,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }
}
