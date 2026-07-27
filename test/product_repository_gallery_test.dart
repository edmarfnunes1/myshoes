import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/app_database.dart';
import 'package:myshoes/data/product_image_repository.dart';
import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/product.dart';
import 'package:myshoes/models/product_image.dart';
import 'package:myshoes/services/product_image_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeProductImageStorageService extends ProductImageStorageService {
  _FakeProductImageStorageService({required Directory baseDirectory})
      : super(baseDirectoryProvider: () async => baseDirectory);

  final List<TemporaryProductImageFiles> committedTemporary = [];
  final List<TemporaryProductImageFiles> removedTemporary = [];
  final List<StoredProductImageFiles> removedStored = [];
  final List<int> removedProducts = [];

  int _nextStoredFile = 0;

  @override
  Future<StoredProductImageFiles> commitTemporary({
    required int productId,
    required TemporaryProductImageFiles temporaryFiles,
  }) async {
    committedTemporary.add(temporaryFiles);
    final index = _nextStoredFile++;
    return StoredProductImageFiles(
      imagePath: '/fake/products/$productId/images/image_$index.jpg',
      thumbnailPath:
          '/fake/products/$productId/thumbnails/image_$index.jpg',
    );
  }

  @override
  Future<void> removeTemporary(TemporaryProductImageFiles files) async {
    removedTemporary.add(files);
  }

  @override
  Future<void> remove({
    required String imagePath,
    required String thumbnailPath,
  }) async {
    removedStored.add(
      StoredProductImageFiles(
        imagePath: imagePath,
        thumbnailPath: thumbnailPath,
      ),
    );
  }

  @override
  Future<void> removeAllForProduct(int productId) async {
    removedProducts.add(productId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late _FakeProductImageStorageService storageService;
  late ProductImageRepository imageRepository;
  late ProductRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myshoes_product_repository_gallery_test_',
    );
    databasePath = '${temporaryDirectory.path}/myshoes_test.db';
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    storageService = _FakeProductImageStorageService(
      baseDirectory: temporaryDirectory,
    );
    imageRepository = ProductImageRepository(
      database: appDatabase,
      storageService: storageService,
    );
    repository = ProductRepository(
      database: appDatabase,
      imageRepository: imageRepository,
      imageStorageService: storageService,
    );
  });

  tearDown(() async {
    await appDatabase.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<Product> createProduct({
    String brand = 'Nike',
    String model = 'Air Force 1',
  }) {
    return repository.save(
      Product(
        brand: brand,
        model: model,
        minimumSize: 34,
        maximumSize: 44,
        costPrice: 120,
        salePrice: 220,
      ),
    );
  }

  TemporaryProductImageFiles temporaryImage(String name) {
    return TemporaryProductImageFiles(
      imagePath: '/temporary/$name.jpg',
      thumbnailPath: '/temporary/${name}_thumb.jpg',
    );
  }

  ProductImage image({
    required int productId,
    required String name,
    required int position,
    bool isPrimary = false,
  }) {
    return ProductImage(
      productId: productId,
      imagePath: '/stored/$name.jpg',
      thumbnailPath: '/stored/${name}_thumb.jpg',
      position: position,
      isPrimary: isPrimary,
      createdAt: DateTime.utc(2026, 7, 27, 12, position),
    );
  }

  group('ProductRepository - galeria de imagens', () {
    test('salva uma galeria completa de imagens temporárias', () async {
      final product = await createProduct();
      final temporary = [
        temporaryImage('front'),
        temporaryImage('side'),
        temporaryImage('back'),
      ];

      final saved = await repository.saveImageGallery(
        productId: product.id!,
        orderedImageIds: const [null, null, null],
        temporaryImages: temporary,
        primaryIndex: 1,
      );

      expect(saved, hasLength(3));
      expect(saved.map((item) => item.position), [0, 1, 2]);
      expect(saved.where((item) => item.isPrimary).single.id, saved[1].id);
      expect(storageService.committedTemporary, temporary);
      expect(storageService.removedTemporary, temporary);
    });

    test('atualiza a imagem principal da galeria', () async {
      final product = await createProduct();
      final inserted = await imageRepository.insertImages([
        image(productId: product.id!, name: 'front', position: 0),
        image(productId: product.id!, name: 'side', position: 1),
      ]);

      final saved = await repository.saveImageGallery(
        productId: product.id!,
        orderedImageIds: inserted.map((item) => item.id).toList(),
        temporaryImages: const [],
        primaryIndex: 1,
      );

      expect(saved.where((item) => item.isPrimary).single.id, inserted[1].id);
      expect(saved.first.isPrimary, isFalse);
    });

    test('reorganiza as posições das imagens existentes', () async {
      final product = await createProduct();
      final inserted = await imageRepository.insertImages([
        image(productId: product.id!, name: 'front', position: 0),
        image(productId: product.id!, name: 'side', position: 1),
        image(productId: product.id!, name: 'back', position: 2),
      ]);

      final saved = await repository.saveImageGallery(
        productId: product.id!,
        orderedImageIds: [inserted[2].id, inserted[0].id, inserted[1].id],
        temporaryImages: const [],
        primaryIndex: 0,
      );

      expect(saved.map((item) => item.id), [
        inserted[2].id,
        inserted[0].id,
        inserted[1].id,
      ]);
      expect(saved.map((item) => item.position), [0, 1, 2]);
    });

    test('exclui da galeria as imagens removidas pelo usuário', () async {
      final product = await createProduct();
      final inserted = await imageRepository.insertImages([
        image(productId: product.id!, name: 'front', position: 0),
        image(productId: product.id!, name: 'side', position: 1),
        image(productId: product.id!, name: 'back', position: 2),
      ]);

      final saved = await repository.saveImageGallery(
        productId: product.id!,
        orderedImageIds: [inserted[0].id, inserted[2].id],
        temporaryImages: const [],
        primaryIndex: 0,
      );

      expect(saved.map((item) => item.id), [inserted[0].id, inserted[2].id]);
      expect(
        await imageRepository.getImagesByProductId(product.id!),
        hasLength(2),
      );
      expect(storageService.removedStored, hasLength(1));
      expect(storageService.removedStored.single.imagePath, inserted[1].imagePath);
    });

    test('findByIdWithImages carrega o tênis e suas imagens', () async {
      final product = await createProduct();
      final inserted = await imageRepository.insertImage(
        image(productId: product.id!, name: 'front', position: 0),
      );

      final found = await repository.findByIdWithImages(product.id!);

      expect(found, isNotNull);
      expect(found!.images, hasLength(1));
      expect(found.images.single.id, inserted.id);
      expect(found.images.single.isPrimary, isTrue);
    });

    test('findAllWithImages carrega as imagens de todos os tênis', () async {
      final first = await createProduct(brand: 'Nike', model: 'Dunk');
      final second = await createProduct(brand: 'Adidas', model: 'Forum');
      await imageRepository.insertImage(
        image(productId: first.id!, name: 'nike', position: 0),
      );
      await imageRepository.insertImages([
        image(productId: second.id!, name: 'adidas_1', position: 0),
        image(productId: second.id!, name: 'adidas_2', position: 1),
      ]);

      final products = await repository.findAllWithImages();
      final nike = products.singleWhere((item) => item.id == first.id);
      final adidas = products.singleWhere((item) => item.id == second.id);

      expect(nike.images, hasLength(1));
      expect(adidas.images, hasLength(2));
    });

    test('retorna produto sem imagens normalmente', () async {
      final product = await createProduct();

      final found = await repository.findByIdWithImages(product.id!);

      expect(found, isNotNull);
      expect(found!.images, isEmpty);
    });

    test('funciona com uma única imagem', () async {
      final product = await createProduct();

      final saved = await repository.saveImageGallery(
        productId: product.id!,
        orderedImageIds: const [null],
        temporaryImages: [temporaryImage('only')],
        primaryIndex: 0,
      );

      expect(saved, hasLength(1));
      expect(saved.single.position, 0);
      expect(saved.single.isPrimary, isTrue);
    });

    test('funciona com o limite de cinco imagens', () async {
      final product = await createProduct();
      final temporary = List.generate(
        5,
        (index) => temporaryImage('image_$index'),
      );

      final saved = await repository.saveImageGallery(
        productId: product.id!,
        orderedImageIds: List<int?>.filled(5, null),
        temporaryImages: temporary,
        primaryIndex: 4,
      );

      expect(saved, hasLength(5));
      expect(saved.map((item) => item.position), [0, 1, 2, 3, 4]);
      expect(saved.where((item) => item.isPrimary).single.id, saved[4].id);
    });

    test('substitui a imagem principal por uma nova imagem', () async {
      final product = await createProduct();
      final existing = await imageRepository.insertImages([
        image(productId: product.id!, name: 'old_primary', position: 0),
        image(productId: product.id!, name: 'kept', position: 1),
      ]);

      final saved = await repository.saveImageGallery(
        productId: product.id!,
        orderedImageIds: [existing[1].id, null],
        temporaryImages: [temporaryImage('new_primary')],
        primaryIndex: 1,
      );

      expect(saved, hasLength(2));
      expect(saved.first.id, existing[1].id);
      expect(saved[1].isPrimary, isTrue);
      expect(saved[1].id, isNot(existing[0].id));
      expect(storageService.removedStored.single.imagePath, existing[0].imagePath);
    });

    test('atualiza a galeria mantendo as imagens existentes', () async {
      final product = await createProduct();
      final existing = await imageRepository.insertImages([
        image(productId: product.id!, name: 'front', position: 0),
        image(productId: product.id!, name: 'side', position: 1),
      ]);

      final saved = await repository.saveImageGallery(
        productId: product.id!,
        orderedImageIds: [existing[1].id, null, existing[0].id],
        temporaryImages: [temporaryImage('detail')],
        primaryIndex: 0,
      );

      expect(saved, hasLength(3));
      expect(saved[0].id, existing[1].id);
      expect(saved[2].id, existing[0].id);
      expect(saved[1].id, isNotNull);
      expect(storageService.removedStored, isEmpty);
    });

    test('exclui fisicamente os arquivos ao excluir o tênis', () async {
      final realStorage = ProductImageStorageService(
        baseDirectoryProvider: () async => temporaryDirectory,
      );
      final realImageRepository = ProductImageRepository(
        database: appDatabase,
        storageService: realStorage,
      );
      final realRepository = ProductRepository(
        database: appDatabase,
        imageRepository: realImageRepository,
        imageStorageService: realStorage,
      );
      final product = await realRepository.save(
        Product(
          brand: 'Puma',
          model: 'Suede',
          minimumSize: 34,
          maximumSize: 44,
          costPrice: 100,
        ),
      );
      final productDirectory = Directory(
        '${temporaryDirectory.path}/myshoes/products/${product.id}',
      );
      final imageFile = File('${productDirectory.path}/images/front.jpg');
      final thumbnailFile =
          File('${productDirectory.path}/thumbnails/front.jpg');
      await imageFile.parent.create(recursive: true);
      await thumbnailFile.parent.create(recursive: true);
      await imageFile.writeAsBytes([1, 2, 3]);
      await thumbnailFile.writeAsBytes([4, 5, 6]);
      await realImageRepository.save(
        ProductImage(
          productId: product.id!,
          imagePath: imageFile.path,
          thumbnailPath: thumbnailFile.path,
          position: 0,
          isPrimary: true,
          createdAt: DateTime.utc(2026, 7, 27),
        ),
      );

      await realRepository.delete(product.id!);

      expect(await productDirectory.exists(), isFalse);
      expect(await realRepository.findByIdWithImages(product.id!), isNull);
    });

    test('faz rollback e remove arquivos commitados quando a galeria falha', () async {
      final firstProduct = await createProduct(model: 'First');
      final secondProduct = await createProduct(model: 'Second');
      final original = await imageRepository.insertImage(
        image(productId: firstProduct.id!, name: 'original', position: 0),
      );
      final foreign = await imageRepository.insertImage(
        image(productId: secondProduct.id!, name: 'foreign', position: 0),
      );

      await expectLater(
        repository.saveImageGallery(
          productId: firstProduct.id!,
          orderedImageIds: [original.id, foreign.id, null],
          temporaryImages: [temporaryImage('new')],
          primaryIndex: 0,
        ),
        throwsA(isA<StateError>()),
      );

      final remaining =
          await imageRepository.getImagesByProductId(firstProduct.id!);
      expect(remaining, hasLength(1));
      expect(remaining.single.id, original.id);
      expect(storageService.removedStored, hasLength(1));
      expect(
        storageService.removedStored.single.imagePath,
        contains('/fake/products/${firstProduct.id}/images/'),
      );
      expect(storageService.removedTemporary, isEmpty);
    });
  });
}
