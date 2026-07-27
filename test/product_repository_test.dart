import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/app_database.dart';
import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/product.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late ProductRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myshoes_product_repository_test_',
    );
    databasePath = '${temporaryDirectory.path}/myshoes_test.db';
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    repository = ProductRepository(database: appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Product product({
    int? id,
    String brand = 'Nike',
    String model = 'Air Force 1',
    int minimumSize = 34,
    int maximumSize = 44,
    double costPrice = 120,
    double? salePrice = 220,
    String? notes = 'Tênis branco',
  }) {
    return Product(
      id: id,
      brand: brand,
      model: model,
      minimumSize: minimumSize,
      maximumSize: maximumSize,
      costPrice: costPrice,
      salePrice: salePrice,
      notes: notes,
    );
  }

  group('ProductRepository', () {
    test('cadastra um tênis e devolve o id gerado', () async {
      final saved = await repository.save(product());

      expect(saved.id, isNotNull);
      expect(saved.brand, 'Nike');
      expect(saved.model, 'Air Force 1');
      expect(saved.minimumSize, 34);
      expect(saved.maximumSize, 44);
      expect(saved.costPrice, 120);
      expect(saved.salePrice, 220);
      expect(saved.notes, 'Tênis branco');
    });

    test('edita todos os dados de um tênis existente', () async {
      final saved = await repository.save(product());

      final updated = await repository.save(
        saved.copyWith(
          brand: 'Adidas',
          model: 'Forum Low',
          minimumSize: 35,
          maximumSize: 43,
          costPrice: 140,
          salePrice: 259.90,
          notes: 'Modelo atualizado',
        ),
      );
      final reloaded = await repository.findByIdWithImages(saved.id!);

      expect(updated.id, saved.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.brand, 'Adidas');
      expect(reloaded.model, 'Forum Low');
      expect(reloaded.minimumSize, 35);
      expect(reloaded.maximumSize, 43);
      expect(reloaded.costPrice, 140);
      expect(reloaded.salePrice, 259.90);
      expect(reloaded.notes, 'Modelo atualizado');
    });

    test('exclui um tênis', () async {
      final saved = await repository.save(product());

      await repository.delete(saved.id!);

      expect(await repository.findByIdWithImages(saved.id!), isNull);
      expect(await repository.findAll(), isEmpty);
    });

    test('busca um tênis pelo id', () async {
      final saved = await repository.save(
        product(brand: 'Puma', model: 'Suede Classic'),
      );

      final found = await repository.findByIdWithImages(saved.id!);

      expect(found, isNotNull);
      expect(found!.id, saved.id);
      expect(found.brand, 'Puma');
      expect(found.model, 'Suede Classic');
      expect(found.images, isEmpty);
    });

    test('retorna null ao buscar um id inexistente', () async {
      expect(await repository.findByIdWithImages(999999), isNull);
    });

    test('lista todos os tênis cadastrados', () async {
      await repository.save(product(brand: 'Nike', model: 'Dunk Low'));
      await repository.save(product(brand: 'Adidas', model: 'Campus 00s'));
      await repository.save(product(brand: 'Puma', model: 'RS-X'));

      final products = await repository.findAll();

      expect(products, hasLength(3));
      expect(products.map((item) => item.model), containsAll(<String>[
        'Dunk Low',
        'Campus 00s',
        'RS-X',
      ]));
    });

    test('pesquisa por marca ignorando maiúsculas e espaços externos', () async {
      await repository.save(product(brand: 'New Balance', model: '530'));
      await repository.save(product(brand: 'Nike', model: 'Air Max 90'));

      final products = await repository.findAll(search: '  new BALANCE  ');

      expect(products, hasLength(1));
      expect(products.single.brand, 'New Balance');
      expect(products.single.model, '530');
    });

    test('pesquisa por parte do modelo ignorando maiúsculas', () async {
      await repository.save(product(brand: 'Nike', model: 'Air Force 1'));
      await repository.save(product(brand: 'Nike', model: 'Dunk Low'));
      await repository.save(product(brand: 'Adidas', model: 'Forum Low'));

      final products = await repository.findAll(search: 'FORCE');

      expect(products, hasLength(1));
      expect(products.single.model, 'Air Force 1');
    });

    test('ordena por marca e depois por modelo sem diferenciar maiúsculas', () async {
      await repository.save(product(brand: 'Puma', model: 'Suede'));
      await repository.save(product(brand: 'nike', model: 'Dunk Low'));
      await repository.save(product(brand: 'Adidas', model: 'Forum'));
      await repository.save(product(brand: 'Nike', model: 'Air Force'));

      final products = await repository.findAll();

      expect(
        products.map((item) => '${item.brand}|${item.model}').toList(),
        <String>[
          'Adidas|Forum',
          'Nike|Air Force',
          'nike|Dunk Low',
          'Puma|Suede',
        ],
      );
    });

    test('persiste a faixa de numeração mínima e máxima', () async {
      final saved = await repository.save(
        product(minimumSize: 28, maximumSize: 36),
      );

      final found = await repository.findByIdWithImages(saved.id!);

      expect(found!.minimumSize, 28);
      expect(found.maximumSize, 36);
    });

    test('lista marcas por quantidade de uso e depois em ordem alfabética', () async {
      await repository.save(product(brand: 'Nike', model: 'Air Force'));
      await repository.save(product(brand: 'Nike', model: 'Dunk'));
      await repository.save(product(brand: 'Puma', model: 'Suede'));
      await repository.save(product(brand: 'Adidas', model: 'Forum'));

      final brands = await repository.findBrands();

      expect(brands, <String>['Nike', 'Adidas', 'Puma']);
    });

    test('mantém marcas e modelos distintos na listagem', () async {
      await repository.save(product(brand: 'Nike', model: 'Air Max 90'));
      await repository.save(product(brand: 'Nike', model: 'Air Max 97'));
      await repository.save(product(brand: 'Adidas', model: 'Samba'));

      final products = await repository.findAll();

      expect(
        products.map((item) => item.brand).toList(),
        <String>['Adidas', 'Nike', 'Nike'],
      );
      expect(
        products.map((item) => item.model).toList(),
        <String>['Samba', 'Air Max 90', 'Air Max 97'],
      );
    });

    test('findAllWithImages retorna os produtos mesmo quando não há fotos', () async {
      await repository.save(product(brand: 'Fila', model: 'Disruptor'));

      final products = await repository.findAllWithImages();

      expect(products, hasLength(1));
      expect(products.single.brand, 'Fila');
      expect(products.single.images, isEmpty);
    });
  });
}
