import 'order_item.dart';

class Order {
  const Order({
    this.id,
    required this.customerName,
    this.customerPhone,
    required this.items,
    this.paymentStatus,
    this.notes,
    this.createdAt,
  });

  final int? id;
  final String customerName;
  final String? customerPhone;
  final List<OrderItem> items;
  final String? paymentStatus;
  final String? notes;
  final DateTime? createdAt;

  double get totalValue => items.fold(0, (sum, item) => sum + item.total);
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'payment_status': paymentStatus,
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
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }
}
