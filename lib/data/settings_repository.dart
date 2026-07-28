import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class SettingsRepository {
  SettingsRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  static const String boxFeeKey = 'box_fee';
  static const double defaultBoxFee = 5.0;

  final AppDatabase _database;

  Future<double> getBoxFee() async {
    final database = await _database.database;
    final rows = await database.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [boxFeeKey],
      limit: 1,
    );
    if (rows.isEmpty) return defaultBoxFee;
    return double.tryParse(rows.first['value'] as String? ?? '') ??
        defaultBoxFee;
  }

  Future<void> saveBoxFee(double value) async {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Não pode ser negativo.');
    }
    final database = await _database.database;
    await database.insert(
      'app_settings',
      {'key': boxFeeKey, 'value': value.toStringAsFixed(2)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
