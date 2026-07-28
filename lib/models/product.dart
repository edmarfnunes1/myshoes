import 'product_image.dart';

class Product {
  const Product({
    this.id,
    required this.brand,
    required this.model,
    required this.minimumSize,
    required this.maximumSize,
    required this.costPrice,
    this.salePrice,
    this.notes,
    this.isActive = true,
    this.images = const [],
  });

  final int? id;
  final String brand;
  final String model;
  final int minimumSize;
  final int maximumSize;
  final double costPrice;
  final double? salePrice;
  final String? notes;
  final bool isActive;
  final List<ProductImage> images;

  Product copyWith({
    int? id,
    String? brand,
    String? model,
    int? minimumSize,
    int? maximumSize,
    double? costPrice,
    double? salePrice,
    bool clearSalePrice = false,
    String? notes,
    bool clearNotes = false,
    bool? isActive,
    List<ProductImage>? images,
  }) {
    return Product(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      minimumSize: minimumSize ?? this.minimumSize,
      maximumSize: maximumSize ?? this.maximumSize,
      costPrice: costPrice ?? this.costPrice,
      salePrice: clearSalePrice ? null : salePrice ?? this.salePrice,
      notes: clearNotes ? null : notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      images: images ?? this.images,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'brand': brand,
        'model': model,
        'minimum_size': minimumSize,
        'maximum_size': maximumSize,
        'cost_price': costPrice,
        'sale_price': salePrice,
        'notes': notes,
        'is_active': isActive ? 1 : 0,
      };

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      brand: map['brand'] as String,
      model: map['model'] as String,
      minimumSize: map['minimum_size'] as int,
      maximumSize: map['maximum_size'] as int,
      costPrice: (map['cost_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}
