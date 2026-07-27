import 'dart:io';

import '../models/product_image.dart';
import '../services/product_image_storage_service.dart';
import 'app_database.dart';

class ProductImageLimitException implements Exception {
  const ProductImageLimitException([
    this.message = 'Cada tênis pode possuir no máximo 5 imagens.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ProductImageRepository {
  ProductImageRepository({
    AppDatabase? database,
    ProductImageStorageService? storageService,
  })  : _database = database ?? AppDatabase.instance,
        _storageService = storageService ?? ProductImageStorageService();

  static const int maxImagesPerProduct = 5;

  final AppDatabase _database;
  final ProductImageStorageService _storageService;

  Future<List<ProductImage>> getImagesByProductId(int productId) async {
    final database = await _database.database;
    final rows = await database.query(
      'product_images',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'position ASC, id ASC',
    );

    return rows.map(ProductImage.fromMap).toList();
  }

  Future<ProductImage?> findPrimaryByProductId(int productId) async {
    final database = await _database.database;
    final rows = await database.query(
      'product_images',
      where: 'product_id = ? AND is_primary = 1',
      whereArgs: [productId],
      orderBy: 'position ASC, id ASC',
      limit: 1,
    );

    return rows.isEmpty ? null : ProductImage.fromMap(rows.first);
  }

  Future<ProductImage> insertImage(ProductImage image) async {
    final inserted = await insertImages([image]);
    return inserted.single;
  }

  Future<List<ProductImage>> insertImages(List<ProductImage> images) async {
    if (images.isEmpty) return const [];

    final productId = images.first.productId;
    if (images.any((image) => image.productId != productId)) {
      throw ArgumentError('Todas as imagens devem pertencer ao mesmo tênis.');
    }

    final database = await _database.database;
    return database.transaction((transaction) async {
      final countRows = await transaction.rawQuery(
        'SELECT COUNT(*) AS total FROM product_images WHERE product_id = ?',
        [productId],
      );
      final currentCount = (countRows.single['total'] as int?) ?? 0;
      if (currentCount + images.length > maxImagesPerProduct) {
        throw const ProductImageLimitException();
      }

      final positionRows = await transaction.rawQuery(
        'SELECT MAX(position) AS max_position FROM product_images WHERE product_id = ?',
        [productId],
      );
      var nextPosition = ((positionRows.single['max_position'] as int?) ?? -1) + 1;
      final shouldAssignPrimary = currentCount == 0;
      final inserted = <ProductImage>[];

      for (var index = 0; index < images.length; index++) {
        final source = images[index];
        final normalized = source.copyWith(
          position: nextPosition++,
          isPrimary: shouldAssignPrimary && index == 0,
          createdAt: source.createdAt,
        );
        final values = normalized.toMap()..remove('id');
        final id = await transaction.insert('product_images', values);
        inserted.add(normalized.copyWith(id: id, createdAt: normalized.createdAt));
      }

      // Protege dados antigos/inconsistentes: se já havia imagens mas nenhuma
      // principal, promove a primeira da ordem.
      final primaryRows = await transaction.rawQuery(
        'SELECT COUNT(*) AS total FROM product_images WHERE product_id = ? AND is_primary = 1',
        [productId],
      );
      final primaryCount = (primaryRows.single['total'] as int?) ?? 0;
      if (primaryCount == 0) {
        final firstRows = await transaction.query(
          'product_images',
          columns: ['id'],
          where: 'product_id = ?',
          whereArgs: [productId],
          orderBy: 'position ASC, id ASC',
          limit: 1,
        );
        if (firstRows.isNotEmpty) {
          await transaction.update(
            'product_images',
            {'is_primary': 1},
            where: 'id = ?',
            whereArgs: [firstRows.first['id']],
          );
        }
      }

      return inserted;
    });
  }

  Future<void> updateImagePosition({
    required int productId,
    required int imageId,
    required int newPosition,
  }) async {
    if (newPosition < 0) {
      throw ArgumentError.value(newPosition, 'newPosition');
    }

    final database = await _database.database;
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'product_images',
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'position ASC, id ASC',
      );
      if (rows.isEmpty) return;

      final images = rows.map(ProductImage.fromMap).toList();
      final currentIndex = images.indexWhere((image) => image.id == imageId);
      if (currentIndex < 0) {
        throw StateError('Imagem não encontrada para o tênis informado.');
      }

      final targetIndex = newPosition.clamp(0, images.length - 1);
      final moved = images.removeAt(currentIndex);
      images.insert(targetIndex, moved);

      for (var index = 0; index < images.length; index++) {
        await transaction.update(
          'product_images',
          {'position': index},
          where: 'id = ? AND product_id = ?',
          whereArgs: [images[index].id, productId],
        );
      }
    });
  }

  Future<void> setPrimaryImage({
    required int productId,
    required int imageId,
  }) async {
    final database = await _database.database;
    await database.transaction((transaction) async {
      final exists = await transaction.query(
        'product_images',
        columns: ['id'],
        where: 'id = ? AND product_id = ?',
        whereArgs: [imageId, productId],
        limit: 1,
      );
      if (exists.isEmpty) {
        throw StateError('Imagem não encontrada para o tênis informado.');
      }

      await transaction.update(
        'product_images',
        {'is_primary': 0},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      await transaction.update(
        'product_images',
        {'is_primary': 1},
        where: 'id = ? AND product_id = ?',
        whereArgs: [imageId, productId],
      );
    });
  }

  Future<void> deleteImage(int imageId) async {
    final database = await _database.database;
    ProductImage? image;

    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'product_images',
        where: 'id = ?',
        whereArgs: [imageId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      image = ProductImage.fromMap(rows.first);

      await transaction.delete(
        'product_images',
        where: 'id = ?',
        whereArgs: [imageId],
      );

      final remainingRows = await transaction.query(
        'product_images',
        where: 'product_id = ?',
        whereArgs: [image!.productId],
        orderBy: 'position ASC, id ASC',
      );

      for (var index = 0; index < remainingRows.length; index++) {
        await transaction.update(
          'product_images',
          {
            'position': index,
            if (image!.isPrimary) 'is_primary': index == 0 ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [remainingRows[index]['id']],
        );
      }
    });

    final deletedImage = image;
    if (deletedImage == null) return;
    if (await File(deletedImage.imagePath).exists() ||
        await File(deletedImage.thumbnailPath).exists()) {
      await _storageService.remove(
        imagePath: deletedImage.imagePath,
        thumbnailPath: deletedImage.thumbnailPath,
      );
    }
  }

  Future<void> deleteImagesByProductId(int productId) async {
    final images = await getImagesByProductId(productId);
    final hasPhysicalFiles = await _hasAnyPhysicalFile(images);

    final database = await _database.database;
    await database.delete(
      'product_images',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    if (hasPhysicalFiles) {
      await _storageService.removeAllForProduct(productId);
    }
  }

  Future<bool> _hasAnyPhysicalFile(List<ProductImage> images) async {
    for (final image in images) {
      if (await File(image.imagePath).exists() ||
          await File(image.thumbnailPath).exists()) {
        return true;
      }
    }
    return false;
  }

  // Compatibilidade com chamadas existentes da Etapa 1.
  Future<List<ProductImage>> findByProductId(int productId) =>
      getImagesByProductId(productId);

  Future<ProductImage> save(ProductImage image) async {
    final database = await _database.database;

    return database.transaction((transaction) async {
      if (image.id == null) {
        final countRows = await transaction.rawQuery(
          'SELECT COUNT(*) AS total FROM product_images WHERE product_id = ?',
          [image.productId],
        );
        final currentCount = (countRows.single['total'] as int?) ?? 0;
        if (currentCount >= maxImagesPerProduct) {
          throw const ProductImageLimitException();
        }

        // Mantém compatibilidade com a API da Etapa 1: save() respeita a
        // posição informada. A nova API insertImage()/insertImages() continua
        // responsável por inserir no final e normalizar a ordem.
        final shouldBePrimary = image.isPrimary || currentCount == 0;
        if (shouldBePrimary) {
          await transaction.update(
            'product_images',
            {'is_primary': 0},
            where: 'product_id = ?',
            whereArgs: [image.productId],
          );
        }

        final normalized = image.copyWith(isPrimary: shouldBePrimary);
        final values = normalized.toMap()..remove('id');
        final id = await transaction.insert('product_images', values);
        return normalized.copyWith(id: id);
      }

      if (image.isPrimary) {
        await transaction.update(
          'product_images',
          {'is_primary': 0},
          where: 'product_id = ?',
          whereArgs: [image.productId],
        );
      }
      await transaction.update(
        'product_images',
        image.toMap()..remove('id'),
        where: 'id = ? AND product_id = ?',
        whereArgs: [image.id, image.productId],
      );
      return image;
    });
  }

  Future<void> setPrimary({required int productId, required int imageId}) =>
      setPrimaryImage(productId: productId, imageId: imageId);

  Future<void> updatePositions(List<ProductImage> images) async {
    for (var index = 0; index < images.length; index++) {
      await updateImagePosition(
        productId: images[index].productId,
        imageId: images[index].id!,
        newPosition: index,
      );
    }
  }

  Future<void> delete(int id) => deleteImage(id);

  Future<void> deleteByProductId(int productId) =>
      deleteImagesByProductId(productId);
}
