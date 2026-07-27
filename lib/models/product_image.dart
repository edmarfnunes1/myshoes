class ProductImage {
  const ProductImage({
    this.id,
    required this.productId,
    required this.imagePath,
    required this.thumbnailPath,
    required this.position,
    required this.isPrimary,
    required this.createdAt,
  });

  final int? id;
  final int productId;
  final String imagePath;
  final String thumbnailPath;
  final int position;
  final bool isPrimary;
  final DateTime createdAt;

  ProductImage copyWith({
    int? id,
    int? productId,
    String? imagePath,
    String? thumbnailPath,
    int? position,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return ProductImage(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      position: position ?? this.position,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'product_id': productId,
        'image_path': imagePath,
        'thumbnail_path': thumbnailPath,
        'position': position,
        'is_primary': isPrimary ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory ProductImage.fromMap(Map<String, Object?> map) {
    return ProductImage(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      imagePath: map['image_path'] as String,
      thumbnailPath: map['thumbnail_path'] as String,
      position: map['position'] as int,
      isPrimary: (map['is_primary'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
