import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/app_database.dart';
import 'package:myshoes/data/settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late AppDatabase database;
  late SettingsRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('settings_');
    database = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${temporaryDirectory.path}/test.db',
    );
    repository = SettingsRepository(database: database);
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('inicia com valor padrão de cinco reais', () async {
    expect(await repository.getBoxFee(), 5.0);
  });

  test('salva valor decimal e permite isenção', () async {
    await repository.saveBoxFee(7.5);
    expect(await repository.getBoxFee(), 7.5);

    await repository.saveBoxFee(0);
    expect(await repository.getBoxFee(), 0);
  });

  test('não permite valor negativo', () async {
    expect(repository.saveBoxFee(-1), throwsArgumentError);
  });
}
