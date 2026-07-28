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
    this.costPriceUnit = 0,
    this.boxFeeUnit = 0,
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
  final double costPriceUnit;
  final double boxFeeUnit;
  final String? productName;

  double get total => unitPrice * quantity;

  double get shoeCostTotal => costPriceUnit * quantity;

  double get boxFeeTotal => boxFeeUnit * quantity;

  double get totalCost => shoeCostTotal + boxFeeTotal;

  double get profit => total - totalCost;

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
    double? costPriceUnit,
    double? boxFeeUnit,
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
      costPriceUnit: costPriceUnit ?? this.costPriceUnit,
      boxFeeUnit: boxFeeUnit ?? this.boxFeeUnit,
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
        'cost_price_unit': costPriceUnit,
        'box_fee_unit': boxFeeUnit,
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
        costPriceUnit: (map['cost_price_unit'] as num? ?? 0).toDouble(),
        boxFeeUnit: (map['box_fee_unit'] as num? ?? 0).toDouble(),
        productName: map['product_name'] as String?,
      );
}
