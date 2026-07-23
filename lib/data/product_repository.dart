import '../models/product.dart';
import 'app_database.dart';

class ProductRepository {
  ProductRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Product>> findAll({String search = ''}) async {
    final database = await _database.database;
    final normalizedSearch = search.trim();

    final rows = await database.query(
      'products',
      where: normalizedSearch.isEmpty
          ? null
          : '(LOWER(brand) LIKE ? OR LOWER(model) LIKE ?)',
      whereArgs: normalizedSearch.isEmpty
          ? null
          : [
              '%${normalizedSearch.toLowerCase()}%',
              '%${normalizedSearch.toLowerCase()}%',
            ],
      orderBy: 'brand COLLATE NOCASE, model COLLATE NOCASE',
    );

    return rows.map(Product.fromMap).toList();
  }

  Future<List<String>> findBrands() async {
    final database = await _database.database;
    final rows = await database.rawQuery('''
      SELECT brand, COUNT(*) AS usage_count
      FROM products
      WHERE TRIM(brand) <> ''
      GROUP BY LOWER(TRIM(brand))
      ORDER BY usage_count DESC, brand COLLATE NOCASE
    ''');

    return rows
        .map((row) => (row['brand'] as String).trim())
        .where((brand) => brand.isNotEmpty)
        .toList();
  }

  Future<Product> save(Product product) async {
    final database = await _database.database;
    final values = product.toMap()..remove('id');

    if (product.id == null) {
      final id = await database.insert('products', values);
      return product.copyWith(id: id);
    }

    await database.update(
      'products',
      values,
      where: 'id = ?',
      whereArgs: [product.id],
    );
    return product;
  }

  Future<void> delete(int id) async {
    final database = await _database.database;
    await database.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
