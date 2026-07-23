import '../models/customer.dart';
import 'app_database.dart';

class CustomerRepository {
  CustomerRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Customer>> findAll({String search = ''}) async {
    final database = await _database.database;
    final normalizedSearch = search.trim().toLowerCase();

    final rows = await database.query(
      'customers',
      where: normalizedSearch.isEmpty
          ? null
          : '(LOWER(name) LIKE ? OR LOWER(phone) LIKE ?)',
      whereArgs: normalizedSearch.isEmpty
          ? null
          : ['%$normalizedSearch%', '%$normalizedSearch%'],
      orderBy: 'name COLLATE NOCASE',
    );

    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer> save(Customer customer) async {
    final database = await _database.database;
    final values = customer.toMap()..remove('id');

    if (customer.id == null) {
      final id = await database.insert('customers', values);
      return customer.copyWith(id: id);
    }

    await database.update(
      'customers',
      values,
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    return customer;
  }

  Future<void> delete(int id) async {
    final database = await _database.database;
    await database.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
