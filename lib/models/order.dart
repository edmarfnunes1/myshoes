class Order {
  const Order({
    this.id,
    required this.customerName,
    this.customerPhone,
    required this.productId,
    required this.shoeSize,
    required this.quantity,
    required this.withBox,
    required this.saleValue,
    this.paymentStatus,
    this.notes,
    this.productName,
    this.createdAt,
  });

  final int? id;
  final String customerName;
  final String? customerPhone;
  final int productId;
  final int shoeSize;
  final int quantity;
  final bool withBox;
  final double saleValue;
  final String? paymentStatus;
  final String? notes;
  final String? productName;
  final DateTime? createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'product_id': productId,
        'shoe_size': shoeSize,
        'quantity': quantity,
        'with_box': withBox ? 1 : 0,
        'sale_value': saleValue,
        'payment_status': paymentStatus,
        'notes': notes,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory Order.fromMap(Map<String, Object?> map) => Order(
        id: map['id'] as int?,
        customerName: map['customer_name'] as String? ?? '',
        customerPhone: map['customer_phone'] as String?,
        productId: map['product_id'] as int,
        shoeSize: map['shoe_size'] as int,
        quantity: map['quantity'] as int,
        withBox: (map['with_box'] as int) == 1,
        saleValue: (map['sale_value'] as num).toDouble(),
        paymentStatus: map['payment_status'] as String?,
        notes: map['notes'] as String?,
        productName: map['product_name'] as String?,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      );
}
