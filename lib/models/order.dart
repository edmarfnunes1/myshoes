import 'order_item.dart';

class Order {
  const Order({
    this.id,
    required this.customerName,
    this.customerPhone,
    required this.items,
    this.paymentStatus,
    this.amountPaid = 0,
    this.notes,
    this.createdAt,
    this.productionBatchId,
  });

  final int? id;
  final String customerName;
  final String? customerPhone;
  final List<OrderItem> items;
  final String? paymentStatus;
  final double amountPaid;
  final String? notes;
  final DateTime? createdAt;
  final int? productionBatchId;

  bool get isInProductionBatch => productionBatchId != null;

  double get totalValue => items.fold(0, (sum, item) => sum + item.total);
  double get shoeCost =>
      items.fold(0, (sum, item) => sum + item.shoeCostTotal);
  double get boxCost => items.fold(0, (sum, item) => sum + item.boxFeeTotal);
  double get totalCost => shoeCost + boxCost;
  double get profit => totalValue - totalCost;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'payment_status': paymentStatus,
        'amount_paid': amountPaid,
        'notes': notes,
        'created_at': _dateOnly(createdAt ?? DateTime.now()),
      };



  static String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  factory Order.fromMap(
    Map<String, Object?> map, {
    List<OrderItem> items = const [],
  }) {
    return Order(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String? ?? '',
      customerPhone: map['customer_phone'] as String?,
      items: items,
      paymentStatus: map['payment_status'] as String?,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      productionBatchId: map['production_batch_id'] as int?,
    );
  }
}
