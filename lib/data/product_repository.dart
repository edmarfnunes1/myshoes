import '../models/product.dart';
import '../models/product_image.dart';
import '../services/product_image_storage_service.dart';
import 'product_image_repository.dart';
import 'app_database.dart';

class ProductRepository {
  ProductRepository({
    AppDatabase? database,
    ProductImageRepository? imageRepository,
    ProductImageStorageService? imageStorageService,
  }) {
    final resolvedDatabase = database ?? AppDatabase.instance;
    final resolvedStorage =
        imageStorageService ?? ProductImageStorageService();
    _database = resolvedDatabase;
    _imageStorageService = resolvedStorage;
    _imageRepository = imageRepository ??
        ProductImageRepository(
          database: resolvedDatabase,
          storageService: resolvedStorage,
        );
  }

  late final AppDatabase _database;
  late final ProductImageRepository _imageRepository;
  late final ProductImageStorageService _imageStorageService;

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

  Future<List<Product>> findAllWithImages({String search = ''}) async {
    final products = await findAll(search: search);
    return Future.wait(
      products.map((product) async {
        if (product.id == null) return product;
        final images = await _imageRepository.findByProductId(product.id!);
        return product.copyWith(images: images);
      }),
    );
  }

  Future<Product?> findByIdWithImages(int id) async {
    final database = await _database.database;
    final rows = await database.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final product = Product.fromMap(rows.first);
    final images = await _imageRepository.findByProductId(id);
    return product.copyWith(images: images);
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


  Future<List<ProductImage>> saveTemporaryImages({
    required int productId,
    required List<TemporaryProductImageFiles> temporaryImages,
  }) async {
    if (temporaryImages.isEmpty) return const [];

    final committed = <StoredProductImageFiles>[];
    try {
      for (final temporary in temporaryImages) {
        committed.add(
          await _imageStorageService.commitTemporary(
            productId: productId,
            temporaryFiles: temporary,
          ),
        );
      }

      final now = DateTime.now();
      final records = committed
          .asMap()
          .entries
          .map(
            (entry) => ProductImage(
              productId: productId,
              imagePath: entry.value.imagePath,
              thumbnailPath: entry.value.thumbnailPath,
              position: entry.key,
              isPrimary: false,
              createdAt: now,
            ),
          )
          .toList();
      final inserted = await _imageRepository.insertImages(records);
      for (final temporary in temporaryImages) {
        await _imageStorageService.removeTemporary(temporary);
      }
      return inserted;
    } catch (_) {
      for (final files in committed) {
        await _imageStorageService.remove(
          imagePath: files.imagePath,
          thumbnailPath: files.thumbnailPath,
        );
      }
      rethrow;
    }
  }


  /// Aplica todas as alterações pendentes da galeria em uma única transação.
  /// Itens nulos em [orderedImageIds] representam as novas imagens temporárias,
  /// na mesma ordem em que aparecem em [temporaryImages].
  Future<List<ProductImage>> saveImageGallery({
    required int productId,
    required List<int?> orderedImageIds,
    required List<TemporaryProductImageFiles> temporaryImages,
    required int primaryIndex,
  }) async {
    if (orderedImageIds.length > ProductImageRepository.maxImagesPerProduct) {
      throw const ProductImageLimitException();
    }
    if (orderedImageIds.where((id) => id == null).length != temporaryImages.length) {
      throw ArgumentError('A quantidade de imagens temporárias não corresponde à ordem informada.');
    }
    if (orderedImageIds.isNotEmpty &&
        (primaryIndex < 0 || primaryIndex >= orderedImageIds.length)) {
      throw ArgumentError.value(primaryIndex, 'primaryIndex');
    }

    final committed = <StoredProductImageFiles>[];
    var persisted = false;
    try {
      for (final temporary in temporaryImages) {
        committed.add(await _imageStorageService.commitTemporary(
          productId: productId,
          temporaryFiles: temporary,
        ));
      }

      final database = await _database.database;
      late List<ProductImage> removedImages;
      final saved = await database.transaction((transaction) async {
        final rows = await transaction.query(
          'product_images',
          where: 'product_id = ?',
          whereArgs: [productId],
          orderBy: 'position ASC, id ASC',
        );
        final existing = rows.map(ProductImage.fromMap).toList();
        final existingById = {for (final image in existing) image.id!: image};
        final retainedIds = orderedImageIds.whereType<int>().toSet();
        if (retainedIds.any((id) => !existingById.containsKey(id))) {
          throw StateError('Uma das imagens salvas não pertence ao tênis informado.');
        }
        removedImages = existing
            .where((image) => !retainedIds.contains(image.id))
            .toList();

        if (removedImages.isNotEmpty) {
          await transaction.delete(
            'product_images',
            where: 'product_id = ? AND id NOT IN (${retainedIds.isEmpty ? '-1' : List.filled(retainedIds.length, '?').join(',')})',
            whereArgs: [productId, ...retainedIds],
          );
        }

        await transaction.update(
          'product_images',
          {'is_primary': 0},
          where: 'product_id = ?',
          whereArgs: [productId],
        );

        var temporaryIndex = 0;
        final resultIds = <int>[];
        for (var position = 0; position < orderedImageIds.length; position++) {
          final existingId = orderedImageIds[position];
          if (existingId != null) {
            await transaction.update(
              'product_images',
              {'position': position},
              where: 'id = ? AND product_id = ?',
              whereArgs: [existingId, productId],
            );
            resultIds.add(existingId);
          } else {
            final files = committed[temporaryIndex++];
            final record = ProductImage(
              productId: productId,
              imagePath: files.imagePath,
              thumbnailPath: files.thumbnailPath,
              position: position,
              isPrimary: false,
              createdAt: DateTime.now(),
            );
            final values = record.toMap()..remove('id');
            resultIds.add(await transaction.insert('product_images', values));
          }
        }

        if (resultIds.isNotEmpty) {
          await transaction.update(
            'product_images',
            {'is_primary': 1},
            where: 'id = ? AND product_id = ?',
            whereArgs: [resultIds[primaryIndex], productId],
          );
        }

        final savedRows = await transaction.query(
          'product_images',
          where: 'product_id = ?',
          whereArgs: [productId],
          orderBy: 'position ASC, id ASC',
        );
        return savedRows.map(ProductImage.fromMap).toList();
      });

      persisted = true;
      for (final temporary in temporaryImages) {
        try {
          await _imageStorageService.removeTemporary(temporary);
        } catch (_) {
          // A galeria já foi persistida; uma limpeza posterior removerá órfãos.
        }
      }
      for (final removed in removedImages) {
        try {
          await _imageStorageService.remove(
            imagePath: removed.imagePath,
            thumbnailPath: removed.thumbnailPath,
          );
        } catch (_) {
          // O registro já foi removido. O arquivo órfão pode ser limpo depois.
        }
      }
      return saved;
    } catch (_) {
      if (!persisted) {
        for (final files in committed) {
          await _imageStorageService.remove(
            imagePath: files.imagePath,
            thumbnailPath: files.thumbnailPath,
          );
        }
      }
      rethrow;
    }
  }

  Future<List<ProductImage>> getImagesByProductId(int productId) =>
      _imageRepository.getImagesByProductId(productId);

  Future<void> delete(int id) async {
    // Remove primeiro os arquivos físicos e os registros de imagens.
    // A exclusão dos registros também seria feita por CASCADE, mas a chamada
    // explícita é necessária para limpar a pasta interna do aplicativo.
    await _imageRepository.deleteImagesByProductId(id);

    final database = await _database.database;
    await database.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
