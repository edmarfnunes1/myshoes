class ProductionBatch {
  const ProductionBatch({
    required this.id,
    required this.createdAt,
    required this.orderCount,
    required this.totalPairs,
  });

  final int id;
  final DateTime createdAt;
  final int orderCount;
  final int totalPairs;

  String get formattedId => id.toString().padLeft(4, '0');
}

class ProductionConsolidationRow {
  const ProductionConsolidationRow({
    required this.brand,
    required this.model,
    required this.color,
    required this.shoeSize,
    required this.withBox,
    required this.withoutBox,
  });

  final String brand;
  final String model;
  final String color;
  final int shoeSize;
  final int withBox;
  final int withoutBox;

  int get total => withBox + withoutBox;
  String get productKey => '$brand\u0000$model\u0000$color';
}
