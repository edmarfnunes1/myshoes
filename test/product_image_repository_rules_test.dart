import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/app_database.dart';
import 'package:myshoes/data/product_image_repository.dart';
import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/product.dart';
import 'package:myshoes/models/product_image.dart';
import 'package:myshoes/services/product_image_storage_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late AppDatabase appDatabase;
  late ProductImageStorageService storageService;
  late ProductImageRepository imageRepository;
  late ProductRepository productRepository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myshoes_image_repository_rules_',
    );
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: path.join(temporaryDirectory.path, 'myshoes.db'),
    );
    storageService = ProductImageStorageService(
      baseDirectoryProvider: () async => temporaryDirectory,
    );
    imageRepository = ProductImageRepository(
      database: appDatabase,
      storageService: storageService,
    );
    productRepository = ProductRepository(
      database: appDatabase,
      imageRepository: imageRepository,
      imageStorageService: storageService,
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<Product> createProduct() {
    return productRepository.save(
      const Product(
        brand: 'Nike',
        model: 'Air Max',
        minimumSize: 34,
        maximumSize: 44,
        costPrice: 100,
      ),
    );
  }

  Future<ProductImage> createImage({
    required int productId,
    required String name,
    int position = 99,
    bool isPrimary = false,
  }) async {
    final imagesDirectory = Directory(
      path.join(
        temporaryDirectory.path,
        'myshoes',
        'products',
        '$productId',
        'images',
      ),
    );
    final thumbnailsDirectory = Directory(
      path.join(
        temporaryDirectory.path,
        'myshoes',
        'products',
        '$productId',
        'thumbnails',
      ),
    );
    await imagesDirectory.create(recursive: true);
    await thumbnailsDirectory.create(recursive: true);

    final imageFile = File(path.join(imagesDirectory.path, '$name.jpg'));
    final thumbnailFile =
        File(path.join(thumbnailsDirectory.path, '$name.jpg'));
    await imageFile.writeAsBytes([1, 2, 3]);
    await thumbnailFile.writeAsBytes([4, 5, 6]);

    return ProductImage(
      productId: productId,
      imagePath: imageFile.path,
      thumbnailPath: thumbnailFile.path,
      position: position,
      isPrimary: isPrimary,
      createdAt: DateTime(2026, 7, 26),
    );
  }

  test('a primeira imagem adicionada vira automaticamente a principal',
      () async {
    final product = await createProduct();
    final image = await createImage(productId: product.id!, name: 'frente');

    final saved = await imageRepository.insertImage(image);
    final images = await imageRepository.getImagesByProductId(product.id!);

    expect(saved.position, 0);
    expect(images.single.isPrimary, isTrue);
  });

  test('cadastra várias imagens preservando a ordem de inserção', () async {
    final product = await createProduct();
    final images = await Future.wait([
      createImage(productId: product.id!, name: 'frente'),
      createImage(productId: product.id!, name: 'lateral'),
      createImage(productId: product.id!, name: 'traseira'),
    ]);

    await imageRepository.insertImages(images);
    final saved = await imageRepository.getImagesByProductId(product.id!);

    expect(saved.map((image) => image.position), [0, 1, 2]);
    expect(
      saved.map((image) => path.basename(image.imagePath)),
      ['frente.jpg', 'lateral.jpg', 'traseira.jpg'],
    );
    expect(saved.where((image) => image.isPrimary), hasLength(1));
    expect(saved.first.isPrimary, isTrue);
  });

  test('impede cadastrar mais de cinco imagens por tênis', () async {
    final product = await createProduct();
    final firstFive = <ProductImage>[];
    for (var index = 0; index < 5; index++) {
      firstFive.add(
        await createImage(productId: product.id!, name: 'imagem_$index'),
      );
    }
    await imageRepository.insertImages(firstFive);
    final sixth =
        await createImage(productId: product.id!, name: 'imagem_6');

    expect(
      () => imageRepository.insertImage(sixth),
      throwsA(isA<ProductImageLimitException>()),
    );
    expect(
      await imageRepository.getImagesByProductId(product.id!),
      hasLength(5),
    );
  });

  test('define uma nova principal mantendo somente uma imagem principal',
      () async {
    final product = await createProduct();
    final inserted = await imageRepository.insertImages([
      await createImage(productId: product.id!, name: 'frente'),
      await createImage(productId: product.id!, name: 'lateral'),
    ]);

    await imageRepository.setPrimaryImage(
      productId: product.id!,
      imageId: inserted.last.id!,
    );
    final images = await imageRepository.getImagesByProductId(product.id!);

    expect(images.where((image) => image.isPrimary), hasLength(1));
    expect(images.last.isPrimary, isTrue);
  });

  test('move uma imagem e normaliza todas as posições', () async {
    final product = await createProduct();
    final inserted = await imageRepository.insertImages([
      await createImage(productId: product.id!, name: 'a'),
      await createImage(productId: product.id!, name: 'b'),
      await createImage(productId: product.id!, name: 'c'),
    ]);

    await imageRepository.updateImagePosition(
      productId: product.id!,
      imageId: inserted.last.id!,
      newPosition: 0,
    );
    final images = await imageRepository.getImagesByProductId(product.id!);

    expect(images.map((image) => path.basename(image.imagePath)), [
      'c.jpg',
      'a.jpg',
      'b.jpg',
    ]);
    expect(images.map((image) => image.position), [0, 1, 2]);
  });

  test('ao excluir a principal remove arquivos e promove a próxima', () async {
    final product = await createProduct();
    final inserted = await imageRepository.insertImages([
      await createImage(productId: product.id!, name: 'principal'),
      await createImage(productId: product.id!, name: 'proxima'),
      await createImage(productId: product.id!, name: 'ultima'),
    ]);
    final deleted = inserted.first;

    await imageRepository.deleteImage(deleted.id!);
    final remaining =
        await imageRepository.getImagesByProductId(product.id!);

    expect(await File(deleted.imagePath).exists(), isFalse);
    expect(await File(deleted.thumbnailPath).exists(), isFalse);
    expect(remaining, hasLength(2));
    expect(remaining.first.isPrimary, isTrue);
    expect(remaining.map((image) => image.position), [0, 1]);
  });

  test('ao excluir o tênis remove registros, imagens e miniaturas', () async {
    final product = await createProduct();
    final inserted = await imageRepository.insertImages([
      await createImage(productId: product.id!, name: 'frente'),
      await createImage(productId: product.id!, name: 'lateral'),
    ]);
    final productDirectory = Directory(
      path.join(
        temporaryDirectory.path,
        'myshoes',
        'products',
        '${product.id}',
      ),
    );

    await productRepository.delete(product.id!);

    expect(await productDirectory.exists(), isFalse);
    expect(
      await imageRepository.getImagesByProductId(product.id!),
      isEmpty,
    );
    expect(await File(inserted.first.imagePath).exists(), isFalse);
  });
}
