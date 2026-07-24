

import '../models/order.dart';
import '../models/order_item.dart';
import '../models/production_batch.dart';
import 'app_database.dart';

class ProductionBatchRepository {
  ProductionBatchRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Order>> findAvailableOrders() async {
    final database = await _database.database;
    final rows = await database.rawQuery('''
      SELECT o.*
      FROM orders o
      WHERE NOT EXISTS (
        SELECT 1 FROM production_batch_orders pbo WHERE pbo.order_id = o.id
      )
      ORDER BY o.created_at DESC, o.id DESC
    ''');
    final result = <Order>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final itemRows = await database.rawQuery('''
        SELECT oi.*, p.brand || ' ' || p.model AS product_name
        FROM order_items oi
        INNER JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
        ORDER BY oi.id
      ''', [id]);
      result.add(Order.fromMap(
        row,
        items: itemRows.map((item) => OrderItem.fromMap(item)).toList(),
      ));
    }
    return result;
  }

  Future<int> createBatch(List<int> orderIds) async {
    if (orderIds.isEmpty) throw ArgumentError('Selecione ao menos um pedido.');
    final database = await _database.database;
    return database.transaction((transaction) async {
      final batchId = await transaction.insert('production_batches', {
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final orderId in orderIds) {
        await transaction.insert('production_batch_orders', {
          'batch_id': batchId,
          'order_id': orderId,
        });
      }
      return batchId;
    });
  }

  Future<List<ProductionBatch>> findBatches() async {
    final database = await _database.database;
    final rows = await database.rawQuery('''
      SELECT pb.id, pb.created_at,
             COUNT(DISTINCT pbo.order_id) AS order_count,
             COALESCE(SUM(oi.quantity), 0) AS total_pairs
      FROM production_batches pb
      LEFT JOIN production_batch_orders pbo ON pbo.batch_id = pb.id
      LEFT JOIN order_items oi ON oi.order_id = pbo.order_id
      GROUP BY pb.id, pb.created_at
      ORDER BY pb.id DESC
    ''');
    return rows.map((row) => ProductionBatch(
      id: row['id'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      orderCount: (row['order_count'] as num).toInt(),
      totalPairs: (row['total_pairs'] as num).toInt(),
    )).toList();
  }

  Future<List<ProductionConsolidationRow>> consolidateBatch(int batchId) async {
    final database = await _database.database;
    final rows = await database.rawQuery('''
      SELECT p.brand, p.model, COALESCE(NULLIF(TRIM(oi.color), ''), 'Sem cor') AS color,
             oi.shoe_size,
             SUM(CASE WHEN oi.with_box = 1 THEN oi.quantity ELSE 0 END) AS with_box,
             SUM(CASE WHEN oi.with_box = 0 THEN oi.quantity ELSE 0 END) AS without_box
      FROM production_batch_orders pbo
      INNER JOIN order_items oi ON oi.order_id = pbo.order_id
      INNER JOIN products p ON p.id = oi.product_id
      WHERE pbo.batch_id = ?
      GROUP BY p.brand, p.model, color, oi.shoe_size
      ORDER BY p.brand COLLATE NOCASE, p.model COLLATE NOCASE, color COLLATE NOCASE, oi.shoe_size
    ''', [batchId]);
    return rows.map((row) => ProductionConsolidationRow(
      brand: row['brand'] as String,
      model: row['model'] as String,
      color: row['color'] as String,
      shoeSize: row['shoe_size'] as int,
      withBox: (row['with_box'] as num).toInt(),
      withoutBox: (row['without_box'] as num).toInt(),
    )).toList();
  }
}
