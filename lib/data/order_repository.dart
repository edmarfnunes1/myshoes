import '../models/order.dart';
import 'app_database.dart';

class OrderRepository {
  OrderRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Order>> findAll({String search = ''}) async {
    final database = await _database.database;
    final normalized = search.trim().toLowerCase();
    final rows = await database.rawQuery('''
      SELECT o.*, p.brand || ' ' || p.model AS product_name
      FROM orders o
      INNER JOIN products p ON p.id = o.product_id
      ${normalized.isEmpty ? '' : 'WHERE LOWER(o.customer_name) LIKE ? OR LOWER(COALESCE(o.customer_phone, \'\')) LIKE ? OR LOWER(p.brand || \' \' || p.model) LIKE ?'}
      ORDER BY o.created_at DESC, o.id DESC
    ''', normalized.isEmpty
        ? null
        : ['%$normalized%', '%$normalized%', '%$normalized%']);
    return rows.map(Order.fromMap).toList();
  }

  Future<void> save(Order order) async {
    final database = await _database.database;
    final values = order.toMap()..remove('id');
    if (order.id == null) {
      await database.insert('orders', values);
    } else {
      values.remove('created_at');
      await database.update(
        'orders',
        values,
        where: 'id = ?',
        whereArgs: [order.id],
      );
    }
  }

  Future<void> delete(int id) async {
    final database = await _database.database;
    await database.delete('orders', where: 'id = ?', whereArgs: [id]);
  }
}
