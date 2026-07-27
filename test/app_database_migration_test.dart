import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  AppDatabase? appDatabase;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myshoes_database_migration_test_',
    );
    databasePath = '${temporaryDirectory.path}/myshoes_test.db';
  });

  tearDown(() async {
    await appDatabase?.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<Database> openCurrentDatabase() async {
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    return appDatabase!.database;
  }

  Future<bool> tableExists(Database database, String tableName) async {
    final rows = await database.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ? AND name = ?',
      whereArgs: <Object?>['table', tableName],
    );
    return rows.isNotEmpty;
  }

  Future<List<String>> indexNames(Database database, String tableName) async {
    final rows = await database.rawQuery('PRAGMA index_list($tableName)');
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<int> insertProduct(
    DatabaseExecutor database, {
    int? id,
    String brand = 'Nike',
    String model = 'Air Force 1',
  }) {
    return database.insert('products', <String, Object?>{
      if (id != null) 'id': id,
      'brand': brand,
      'model': model,
      'minimum_size': 34,
      'maximum_size': 44,
      'cost_price': 100.0,
      'sale_price': 180.0,
      'notes': null,
    });
  }

  group('AppDatabase - criação e índices', () {
    test('cria todas as tabelas e índices da versão atual', () async {
      final database = await openCurrentDatabase();

      expect(await database.getVersion(), 9);
      expect(await tableExists(database, 'products'), isTrue);
      expect(await tableExists(database, 'customers'), isTrue);
      expect(await tableExists(database, 'orders'), isTrue);
      expect(await tableExists(database, 'order_items'), isTrue);
      expect(await tableExists(database, 'production_batches'), isTrue);
      expect(await tableExists(database, 'production_batch_orders'), isTrue);
      expect(await tableExists(database, 'product_images'), isTrue);

      expect(
        await indexNames(database, 'order_items'),
        contains('idx_order_items_order_id'),
      );
      expect(
        await indexNames(database, 'production_batch_orders'),
        contains('idx_batch_orders_batch_id'),
      );
      expect(
        await indexNames(database, 'product_images'),
        containsAll(<String>[
          'idx_product_images_product_id',
          'idx_product_images_one_primary',
        ]),
      );
    });

    test('habilita chaves estrangeiras em toda abertura do banco', () async {
      final database = await openCurrentDatabase();

      final result = await database.rawQuery('PRAGMA foreign_keys');

      expect(result.single.values.single, 1);
    });

    test('índice parcial impede duas imagens principais no mesmo tênis',
        () async {
      final database = await openCurrentDatabase();
      final productId = await insertProduct(database);

      await database.insert('product_images', <String, Object?>{
        'product_id': productId,
        'image_path': '/images/frente.webp',
        'thumbnail_path': '/thumbs/frente.webp',
        'position': 0,
        'is_primary': 1,
        'created_at': '2026-07-27T12:00:00.000Z',
      });

      expect(
        () => database.insert('product_images', <String, Object?>{
          'product_id': productId,
          'image_path': '/images/lateral.webp',
          'thumbnail_path': '/thumbs/lateral.webp',
          'position': 1,
          'is_primary': 1,
          'created_at': '2026-07-27T12:01:00.000Z',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('AppDatabase - migrações', () {
    test('abre banco da versão 1 e cria toda a estrutura sem perder tênis',
        () async {
      final oldDatabase = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                brand TEXT NOT NULL,
                model TEXT NOT NULL,
                minimum_size INTEGER NOT NULL,
                maximum_size INTEGER NOT NULL,
                cost_price REAL NOT NULL,
                sale_price REAL,
                notes TEXT
              )
            ''');
          },
        ),
      );
      await insertProduct(
        oldDatabase,
        id: 10,
        brand: 'Adidas',
        model: 'Campus',
      );
      await oldDatabase.close();

      final database = await openCurrentDatabase();
      final products = await database.query(
        'products',
        where: 'id = ?',
        whereArgs: <Object?>[10],
      );

      expect(await database.getVersion(), 9);
      expect(products, hasLength(1));
      expect(products.single['brand'], 'Adidas');
      expect(products.single['model'], 'Campus');
      expect(await tableExists(database, 'customers'), isTrue);
      expect(await tableExists(database, 'orders'), isTrue);
      expect(await tableExists(database, 'order_items'), isTrue);
      expect(await tableExists(database, 'production_batches'), isTrue);
      expect(await tableExists(database, 'product_images'), isTrue);
    });

    test('migra pedido da versão 3 para pedidos com itens', () async {
      final oldDatabase = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                brand TEXT NOT NULL,
                model TEXT NOT NULL,
                minimum_size INTEGER NOT NULL,
                maximum_size INTEGER NOT NULL,
                cost_price REAL NOT NULL,
                sale_price REAL,
                notes TEXT
              )
            ''');
            await database.execute('''
              CREATE TABLE customers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                phone TEXT,
                notes TEXT
              )
            ''');
            await database.execute('''
              CREATE TABLE orders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_id INTEGER,
                product_id INTEGER NOT NULL,
                shoe_size INTEGER NOT NULL,
                color TEXT,
                quantity INTEGER NOT NULL,
                with_box INTEGER NOT NULL DEFAULT 0,
                sale_value REAL NOT NULL,
                payment_status TEXT,
                notes TEXT,
                created_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      await insertProduct(oldDatabase, id: 1);
      await oldDatabase.insert('customers', <String, Object?>{
        'id': 5,
        'name': 'Cliente antigo',
        'phone': '44999999999',
        'notes': null,
      });
      await oldDatabase.insert('orders', <String, Object?>{
        'id': 7,
        'customer_id': 5,
        'product_id': 1,
        'shoe_size': 38,
        'color': 'Preto',
        'quantity': 2,
        'with_box': 1,
        'sale_value': 199.90,
        'payment_status': 'Pendente',
        'notes': 'Pedido legado',
        'created_at': '2026-06-15T18:30:00.000',
      });
      await oldDatabase.close();

      final database = await openCurrentDatabase();
      final orders = await database.query(
        'orders',
        where: 'id = ?',
        whereArgs: <Object?>[7],
      );
      final items = await database.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: <Object?>[7],
      );

      expect(await database.getVersion(), 9);
      expect(orders, hasLength(1));
      expect(orders.single['customer_name'], 'Cliente antigo');
      expect(orders.single['customer_phone'], '44999999999');
      expect(orders.single['payment_status'], 'Pendente');
      expect(orders.single['created_at'], '2026-06-15');

      expect(items, hasLength(1));
      expect(items.single['product_id'], 1);
      expect(items.single['shoe_size'], 38);
      expect(items.single['quantity'], 2);
      expect(items.single['with_box'], 1);
      expect(items.single['unit_price'], 199.90);
      expect(items.single['color'], isNull);
    });

    test('migra banco da versão 6, ajusta data e cria lotes e imagens',
        () async {
      final oldDatabase = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                brand TEXT NOT NULL,
                model TEXT NOT NULL,
                minimum_size INTEGER NOT NULL,
                maximum_size INTEGER NOT NULL,
                cost_price REAL NOT NULL,
                sale_price REAL,
                notes TEXT
              )
            ''');
            await database.execute('''
              CREATE TABLE orders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_name TEXT NOT NULL,
                customer_phone TEXT,
                payment_status TEXT,
                notes TEXT,
                created_at TEXT NOT NULL
              )
            ''');
            await database.execute('''
              CREATE TABLE order_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                shoe_size INTEGER NOT NULL,
                color TEXT,
                quantity INTEGER NOT NULL,
                with_box INTEGER NOT NULL DEFAULT 0,
                unit_price REAL NOT NULL,
                FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
                FOREIGN KEY (product_id) REFERENCES products(id)
              )
            ''');
          },
        ),
      );
      await oldDatabase.insert('orders', <String, Object?>{
        'id': 20,
        'customer_name': 'Cliente data antiga',
        'customer_phone': null,
        'payment_status': 'Pago',
        'notes': null,
        'created_at': '2026-07-01T21:45:30.000',
      });
      await oldDatabase.close();

      final database = await openCurrentDatabase();
      final order = await database.query(
        'orders',
        where: 'id = ?',
        whereArgs: <Object?>[20],
      );

      expect(await database.getVersion(), 9);
      expect(order.single['created_at'], '2026-07-01');
      expect(await tableExists(database, 'production_batches'), isTrue);
      expect(await tableExists(database, 'production_batch_orders'), isTrue);
      expect(await tableExists(database, 'product_images'), isTrue);
    });
  });

  group('AppDatabase - integridade dos relacionamentos', () {
    test('impede item de pedido com pedido ou tênis inexistente', () async {
      final database = await openCurrentDatabase();
      final productId = await insertProduct(database);
      final orderId = await database.insert('orders', <String, Object?>{
        'customer_name': 'Cliente',
        'customer_phone': null,
        'payment_status': 'Pendente',
        'notes': null,
        'created_at': '2026-07-27',
      });

      expect(
        () => database.insert('order_items', <String, Object?>{
          'order_id': 99999,
          'product_id': productId,
          'shoe_size': 38,
          'color': 'Preto',
          'quantity': 1,
          'with_box': 1,
          'unit_price': 150.0,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => database.insert('order_items', <String, Object?>{
          'order_id': orderId,
          'product_id': 99999,
          'shoe_size': 38,
          'color': 'Preto',
          'quantity': 1,
          'with_box': 1,
          'unit_price': 150.0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('excluir pedido remove seus itens em cascata', () async {
      final database = await openCurrentDatabase();
      final productId = await insertProduct(database);
      final orderId = await database.insert('orders', <String, Object?>{
        'customer_name': 'Cliente',
        'customer_phone': null,
        'payment_status': 'Pendente',
        'notes': null,
        'created_at': '2026-07-27',
      });
      await database.insert('order_items', <String, Object?>{
        'order_id': orderId,
        'product_id': productId,
        'shoe_size': 38,
        'color': 'Branco',
        'quantity': 2,
        'with_box': 0,
        'unit_price': 180.0,
      });

      await database.delete(
        'orders',
        where: 'id = ?',
        whereArgs: <Object?>[orderId],
      );

      final items = await database.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: <Object?>[orderId],
      );
      expect(items, isEmpty);
    });

    test('excluir tênis remove imagens, mas é bloqueado quando há pedido',
        () async {
      final database = await openCurrentDatabase();
      final productWithImage = await insertProduct(
        database,
        model: 'Com imagem',
      );
      await database.insert('product_images', <String, Object?>{
        'product_id': productWithImage,
        'image_path': '/images/tenis.webp',
        'thumbnail_path': '/thumbs/tenis.webp',
        'position': 0,
        'is_primary': 1,
        'created_at': '2026-07-27T12:00:00.000Z',
      });

      await database.delete(
        'products',
        where: 'id = ?',
        whereArgs: <Object?>[productWithImage],
      );
      final remainingImages = await database.query(
        'product_images',
        where: 'product_id = ?',
        whereArgs: <Object?>[productWithImage],
      );
      expect(remainingImages, isEmpty);

      final productInOrder = await insertProduct(
        database,
        model: 'Vinculado ao pedido',
      );
      final orderId = await database.insert('orders', <String, Object?>{
        'customer_name': 'Cliente',
        'customer_phone': null,
        'payment_status': 'Pendente',
        'notes': null,
        'created_at': '2026-07-27',
      });
      await database.insert('order_items', <String, Object?>{
        'order_id': orderId,
        'product_id': productInOrder,
        'shoe_size': 40,
        'color': null,
        'quantity': 1,
        'with_box': 1,
        'unit_price': 200.0,
      });

      expect(
        () => database.delete(
          'products',
          where: 'id = ?',
          whereArgs: <Object?>[productInOrder],
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('lote remove vínculos em cascata e protege pedido vinculado',
        () async {
      final database = await openCurrentDatabase();
      final orderId = await database.insert('orders', <String, Object?>{
        'customer_name': 'Cliente da fábrica',
        'customer_phone': null,
        'payment_status': 'Pago',
        'notes': null,
        'created_at': '2026-07-27',
      });
      final batchId = await database.insert(
        'production_batches',
        <String, Object?>{'created_at': '2026-07-27T12:00:00.000Z'},
      );
      await database.insert('production_batch_orders', <String, Object?>{
        'batch_id': batchId,
        'order_id': orderId,
      });

      expect(
        () => database.delete(
          'orders',
          where: 'id = ?',
          whereArgs: <Object?>[orderId],
        ),
        throwsA(isA<DatabaseException>()),
      );

      await database.delete(
        'production_batches',
        where: 'id = ?',
        whereArgs: <Object?>[batchId],
      );

      final links = await database.query(
        'production_batch_orders',
        where: 'batch_id = ?',
        whereArgs: <Object?>[batchId],
      );
      expect(links, isEmpty);
    });
  });
}
