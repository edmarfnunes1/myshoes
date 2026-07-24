import 'package:sqflite/sqflite.dart';

import '../models/order.dart';
import '../models/order_item.dart';
import 'app_database.dart';

class OrderRepository {
  OrderRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Order>> findAll({String search = ''}) async {
    final database = await _database.database;
    final normalized = search.trim().toLowerCase();
    final idSearch = normalized.startsWith('#')
        ? normalized.substring(1).trim()
        : normalized;

    final rows = await database.rawQuery(
      '''
      SELECT DISTINCT o.*
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN products p ON p.id = oi.product_id
      ${normalized.isEmpty ? '' : '''
      WHERE LOWER(o.customer_name) LIKE ?
         OR LOWER(COALESCE(o.customer_phone, '')) LIKE ?
         OR LOWER(COALESCE(p.brand || ' ' || p.model, '')) LIKE ?
         OR LOWER(COALESCE(oi.color, '')) LIKE ?
         OR CAST(o.id AS TEXT) = ?
         OR strftime('%d/%m/%Y', o.created_at) LIKE ?
      '''}
      ORDER BY o.created_at DESC, o.customer_name COLLATE NOCASE ASC, o.id DESC
      ''',
      normalized.isEmpty
          ? null
          : [
              '%$normalized%',
              '%$normalized%',
              '%$normalized%',
              '%$normalized%',
              idSearch,
              '%$normalized%',
            ],
    );

    final orders = <Order>[];
    for (final row in rows) {
      final orderId = row['id'] as int;
      final items = await _findItems(database, orderId);
      orders.add(Order.fromMap(row, items: items));
    }
    return orders;
  }

  Future<Order?> findById(int id) async {
    final database = await _database.database;
    final rows = await database.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await _findItems(database, id);
    return Order.fromMap(rows.first, items: items);
  }

  Future<List<OrderItem>> _findItems(
    DatabaseExecutor database,
    int orderId,
  ) async {
    final rows = await database.rawQuery('''
      SELECT oi.*, p.brand || ' ' || p.model AS product_name
      FROM order_items oi
      INNER JOIN products p ON p.id = oi.product_id
      WHERE oi.order_id = ?
      ORDER BY oi.id
    ''', [orderId]);
    return rows.map<OrderItem>(OrderItem.fromMap).toList();
  }

  Future<void> save(Order order) async {
    final database = await _database.database;
    await database.transaction((transaction) async {
      final values = order.toMap()..remove('id');
      late final int orderId;

      if (order.id == null) {
        orderId = await transaction.insert('orders', values);
      } else {
        orderId = order.id!;
        values.remove('created_at');
        await transaction.update(
          'orders',
          values,
          where: 'id = ?',
          whereArgs: [orderId],
        );
        await transaction.delete(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
      }

      for (final item in order.items) {
        final itemValues = item.copyWith(orderId: orderId).toMap()
          ..remove('id');
        await transaction.insert('order_items', itemValues);
      }
    });
  }

  Future<void> delete(int id) async {
    final database = await _database.database;
    await database.delete('orders', where: 'id = ?', whereArgs: [id]);
  }
}
