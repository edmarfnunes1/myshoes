import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/app_database.dart';
import 'package:myshoes/data/product_image_repository.dart';
import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/product.dart';
import 'package:myshoes/models/product_image.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late ProductRepository productRepository;
  late ProductImageRepository imageRepository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myshoes_product_images_test_',
    );
    databasePath = '${temporaryDirectory.path}/myshoes_test.db';
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    productRepository = ProductRepository(database: appDatabase);
    imageRepository = ProductImageRepository(database: appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<Product> createProduct({String model = 'Air Force 1'}) {
    return productRepository.save(
      Product(
        brand: 'Nike',
        model: model,
        minimumSize: 34,
        maximumSize: 44,
        costPrice: 100,
        salePrice: 180,
      ),
    );
  }

  ProductImage createImage({
    required int productId,
    required String name,
    required int position,
    bool isPrimary = false,
  }) {
    return ProductImage(
      productId: productId,
      imagePath: '/images/$name.webp',
      thumbnailPath: '/thumbnails/$name.webp',
      position: position,
      isPrimary: isPrimary,
      createdAt: DateTime.utc(2026, 7, 26, 12, position),
    );
  }

  group('Banco de imagens dos tênis', () {
    test('cria a tabela product_images com todas as colunas', () async {
      final database = await appDatabase.database;

      final tables = await database.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ? AND name = ?',
        whereArgs: ['table', 'product_images'],
      );
      final columns = await database.rawQuery(
        'PRAGMA table_info(product_images)',
      );

      expect(tables, hasLength(1));
      expect(
        columns.map((column) => column['name']),
        containsAll(<String>[
          'id',
          'product_id',
          'image_path',
          'thumbnail_path',
          'position',
          'is_primary',
          'created_at',
        ]),
      );
    });

    test('cadastra várias imagens para o mesmo tênis', () async {
      final product = await createProduct();

      await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'frente',
          position: 0,
          isPrimary: true,
        ),
      );
      await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'lateral',
          position: 1,
        ),
      );
      await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'traseira',
          position: 2,
        ),
      );

      final images = await imageRepository.findByProductId(product.id!);

      expect(images, hasLength(3));
      expect(images.map((image) => image.productId), everyElement(product.id));
    });

    test('recupera as imagens pela posição e usa o id como desempate', () async {
      final product = await createProduct();

      final second = await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'segunda',
          position: 2,
        ),
      );
      final firstA = await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'primeira-a',
          position: 0,
          isPrimary: true,
        ),
      );
      final firstB = await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'primeira-b',
          position: 0,
        ),
      );

      final images = await imageRepository.findByProductId(product.id!);

      expect(
        images.map((image) => image.id),
        <int?>[firstA.id, firstB.id, second.id],
      );
      expect(images.map((image) => image.position), <int>[0, 0, 2]);
    });

    test('altera a imagem principal e desmarca a anterior', () async {
      final product = await createProduct();
      final first = await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'frente',
          position: 0,
          isPrimary: true,
        ),
      );
      final second = await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'lateral',
          position: 1,
        ),
      );

      await imageRepository.setPrimary(
        productId: product.id!,
        imageId: second.id!,
      );

      final images = await imageRepository.findByProductId(product.id!);
      final primary = await imageRepository.findPrimaryByProductId(product.id!);

      expect(primary?.id, second.id);
      expect(
        images.singleWhere((image) => image.id == first.id).isPrimary,
        isFalse,
      );
      expect(
        images.singleWhere((image) => image.id == second.id).isPrimary,
        isTrue,
      );
    });

    test('mantém somente uma imagem principal por tênis', () async {
      final product = await createProduct();
      await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'frente',
          position: 0,
          isPrimary: true,
        ),
      );

      final newestPrimary = await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'lateral',
          position: 1,
          isPrimary: true,
        ),
      );

      final database = await appDatabase.database;
      final result = await database.rawQuery(
        '''
        SELECT COUNT(*) AS total
        FROM product_images
        WHERE product_id = ? AND is_primary = 1
        ''',
        [product.id],
      );
      final primary = await imageRepository.findPrimaryByProductId(product.id!);

      expect(result.single['total'], 1);
      expect(primary?.id, newestPrimary.id);
    });

    test('remove somente a imagem informada', () async {
      final product = await createProduct();
      final first = await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'frente',
          position: 0,
          isPrimary: true,
        ),
      );
      final second = await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'lateral',
          position: 1,
        ),
      );

      await imageRepository.delete(first.id!);

      final images = await imageRepository.findByProductId(product.id!);

      expect(images, hasLength(1));
      expect(images.single.id, second.id);
    });

    test('remove todas as imagens ao excluir o tênis', () async {
      final product = await createProduct();
      await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'frente',
          position: 0,
          isPrimary: true,
        ),
      );
      await imageRepository.save(
        createImage(
          productId: product.id!,
          name: 'lateral',
          position: 1,
        ),
      );

      await productRepository.delete(product.id!);

      final images = await imageRepository.findByProductId(product.id!);
      final database = await appDatabase.database;
      final products = await database.query(
        'products',
        where: 'id = ?',
        whereArgs: [product.id],
      );

      expect(products, isEmpty);
      expect(images, isEmpty);
    });
  });

  test('migra banco da versão 8 sem perder os tênis existentes', () async {
    await appDatabase.close();

    final oldDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 8,
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
    await oldDatabase.insert('products', <String, Object?>{
      'id': 42,
      'brand': 'Adidas',
      'model': 'Campus',
      'minimum_size': 34,
      'maximum_size': 39,
      'cost_price': 95.0,
      'sale_price': 170.0,
      'notes': 'Cadastro anterior à galeria',
    });
    await oldDatabase.close();

    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    productRepository = ProductRepository(database: appDatabase);
    imageRepository = ProductImageRepository(database: appDatabase);

    final database = await appDatabase.database;
    final products = await database.query(
      'products',
      where: 'id = ?',
      whereArgs: [42],
    );
    final imageTables = await database.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', 'product_images'],
    );
    final version = await database.getVersion();

    expect(version, 9);
    expect(imageTables, hasLength(1));
    expect(products, hasLength(1));
    expect(products.single['brand'], 'Adidas');
    expect(products.single['model'], 'Campus');
    expect(products.single['notes'], 'Cadastro anterior à galeria');
  });
}
