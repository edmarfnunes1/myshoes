class OrderItem {
  const OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.shoeSize,
    this.color,
    required this.quantity,
    required this.withBox,
    required this.unitPrice,
    this.productName,
  });

  final int? id;
  final int? orderId;
  final int productId;
  final int shoeSize;
  final String? color;
  final int quantity;
  final bool withBox;
  final double unitPrice;
  final String? productName;

  double get total => unitPrice * quantity;

  OrderItem copyWith({
    int? id,
    int? orderId,
    int? productId,
    int? shoeSize,
    String? color,
    bool clearColor = false,
    int? quantity,
    bool? withBox,
    double? unitPrice,
    String? productName,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      shoeSize: shoeSize ?? this.shoeSize,
      color: clearColor ? null : color ?? this.color,
      quantity: quantity ?? this.quantity,
      withBox: withBox ?? this.withBox,
      unitPrice: unitPrice ?? this.unitPrice,
      productName: productName ?? this.productName,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'shoe_size': shoeSize,
        'color': color,
        'quantity': quantity,
        'with_box': withBox ? 1 : 0,
        'unit_price': unitPrice,
      };

  factory OrderItem.fromMap(Map<String, Object?> map) => OrderItem(
        id: map['id'] as int?,
        orderId: map['order_id'] as int?,
        productId: map['product_id'] as int,
        shoeSize: map['shoe_size'] as int,
        color: map['color'] as String?,
        quantity: map['quantity'] as int,
        withBox: (map['with_box'] as int? ?? 0) == 1,
        unitPrice: (map['unit_price'] as num).toDouble(),
        productName: map['product_name'] as String?,
      );
}
