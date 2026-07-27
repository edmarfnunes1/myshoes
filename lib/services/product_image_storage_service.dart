import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Caminhos dos dois arquivos gerados para uma foto de tênis.
class TemporaryProductImageFiles {
  const TemporaryProductImageFiles({
    required this.imagePath,
    required this.thumbnailPath,
  });

  final String imagePath;
  final String thumbnailPath;
}

class StoredProductImageFiles {
  const StoredProductImageFiles({
    required this.imagePath,
    required this.thumbnailPath,
  });

  final String imagePath;
  final String thumbnailPath;
}

class ProductImageStorageException implements Exception {
  const ProductImageStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Centraliza a validação, otimização e persistência das imagens dos tênis.
///
/// As imagens finais são salvas em JPEG porque esse formato tem suporte
/// consistente no Android e oferece boa compactação para fotografias.
class ProductImageStorageService {
  ProductImageStorageService({
    Future<Directory> Function()? baseDirectoryProvider,
    Random? random,
  })  : _baseDirectoryProvider =
            baseDirectoryProvider ?? getApplicationSupportDirectory,
        _random = random ?? Random.secure();

  static const int maxImageDimension = 1200;
  static const int thumbnailDimension = 300;
  static const int imageQuality = 80;
  static const int thumbnailQuality = 70;

  static const Set<String> _supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  final Future<Directory> Function() _baseDirectoryProvider;
  final Random _random;


  /// Valida e otimiza uma imagem em uma área temporária do aplicativo.
  Future<TemporaryProductImageFiles> prepareTemporary({
    required File sourceFile,
  }) async {
    final processed = await _processSource(sourceFile);
    final tempRoot = await _temporaryRoot();
    final sessionDirectory = Directory(
      path.join(tempRoot.path, _uniqueName()),
    );
    final imagesDirectory = Directory(path.join(sessionDirectory.path, 'images'));
    final thumbnailsDirectory =
        Directory(path.join(sessionDirectory.path, 'thumbnails'));

    await imagesDirectory.create(recursive: true);
    await thumbnailsDirectory.create(recursive: true);

    final fileName = '${_uniqueName()}.jpg';
    final imageFile = File(path.join(imagesDirectory.path, fileName));
    final thumbnailFile = File(path.join(thumbnailsDirectory.path, fileName));

    try {
      await _writeProcessedFiles(
        imageFile: imageFile,
        thumbnailFile: thumbnailFile,
        optimized: processed.$1,
        thumbnail: processed.$2,
      );
    } catch (_) {
      if (await sessionDirectory.exists()) {
        await sessionDirectory.delete(recursive: true);
      }
      rethrow;
    }

    return TemporaryProductImageFiles(
      imagePath: imageFile.path,
      thumbnailPath: thumbnailFile.path,
    );
  }

  /// Move uma imagem temporária para a pasta definitiva do tênis.
  Future<StoredProductImageFiles> commitTemporary({
    required int productId,
    required TemporaryProductImageFiles temporaryFiles,
  }) async {
    if (productId <= 0) {
      throw const ProductImageStorageException(
        'O identificador do tênis deve ser maior que zero.',
      );
    }

    final sourceImage = File(temporaryFiles.imagePath);
    final sourceThumbnail = File(temporaryFiles.thumbnailPath);
    if (!await sourceImage.exists() || !await sourceThumbnail.exists()) {
      throw const ProductImageStorageException(
        'Uma das imagens temporárias não foi encontrada.',
      );
    }

    final productDirectory = await _productDirectory(productId);
    final imagesDirectory = Directory(path.join(productDirectory.path, 'images'));
    final thumbnailsDirectory =
        Directory(path.join(productDirectory.path, 'thumbnails'));
    await imagesDirectory.create(recursive: true);
    await thumbnailsDirectory.create(recursive: true);

    final fileName = '${_uniqueName()}.jpg';
    final targetImage = File(path.join(imagesDirectory.path, fileName));
    final targetThumbnail = File(path.join(thumbnailsDirectory.path, fileName));

    try {
      await sourceImage.copy(targetImage.path);
      await sourceThumbnail.copy(targetThumbnail.path);
    } catch (error) {
      await _deleteIfExists(targetImage);
      await _deleteIfExists(targetThumbnail);
      throw ProductImageStorageException(
        'Não foi possível concluir o salvamento da foto. Verifique o espaço disponível no aparelho. ($error)',
      );
    }

    return StoredProductImageFiles(
      imagePath: targetImage.path,
      thumbnailPath: targetThumbnail.path,
    );
  }

  Future<void> removeTemporary(TemporaryProductImageFiles files) async {
    await _deleteTemporaryManagedFile(files.imagePath);
    await _deleteTemporaryManagedFile(files.thumbnailPath);
    final sessionDirectory = Directory(
      path.dirname(path.dirname(files.imagePath)),
    );
    if (await sessionDirectory.exists()) {
      await sessionDirectory.delete(recursive: true);
    }
  }

  /// Processa um arquivo temporário e cria a imagem otimizada e a miniatura.
  Future<StoredProductImageFiles> store({
    required int productId,
    required File sourceFile,
  }) async {
    if (productId <= 0) {
      throw const ProductImageStorageException(
        'O identificador do tênis deve ser maior que zero.',
      );
    }

    final processed = await _processSource(sourceFile);
    final optimized = processed.$1;
    final thumbnail = processed.$2;

    final productDirectory = await _productDirectory(productId);
    final imagesDirectory = Directory(path.join(productDirectory.path, 'images'));
    final thumbnailsDirectory =
        Directory(path.join(productDirectory.path, 'thumbnails'));

    await imagesDirectory.create(recursive: true);
    await thumbnailsDirectory.create(recursive: true);

    final fileName = '${_uniqueName()}.jpg';
    final imageFile = File(path.join(imagesDirectory.path, fileName));
    final thumbnailFile = File(path.join(thumbnailsDirectory.path, fileName));

    await _writeProcessedFiles(
      imageFile: imageFile,
      thumbnailFile: thumbnailFile,
      optimized: optimized,
      thumbnail: thumbnail,
    );

    return StoredProductImageFiles(
      imagePath: imageFile.path,
      thumbnailPath: thumbnailFile.path,
    );
  }

  /// Remove a imagem otimizada e sua miniatura.
  Future<void> remove({
    required String imagePath,
    required String thumbnailPath,
  }) async {
    await _deleteManagedFile(imagePath);
    await _deleteManagedFile(thumbnailPath);
  }

  /// Remove todos os arquivos internos associados ao tênis.
  Future<void> removeAllForProduct(int productId) async {
    final directory = await _productDirectory(productId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Exclui arquivos órfãos e mantém somente os caminhos informados.
  Future<void> removeUnusedFiles({
    required int productId,
    required Iterable<String> usedPaths,
  }) async {
    final productDirectory = await _productDirectory(productId);
    if (!await productDirectory.exists()) return;

    final normalizedUsedPaths = usedPaths
        .where((value) => value.trim().isNotEmpty)
        .map((value) => path.normalize(File(value).absolute.path))
        .toSet();

    await for (final entity in productDirectory.list(recursive: true)) {
      if (entity is! File) continue;
      final normalizedPath = path.normalize(entity.absolute.path);
      if (!normalizedUsedPaths.contains(normalizedPath)) {
        await entity.delete();
      }
    }

    await _deleteEmptyDirectories(productDirectory);
  }


  Future<(img.Image, img.Image)> _processSource(File sourceFile) async {
    await _validateSource(sourceFile);

    final Uint8List bytes;
    try {
      bytes = await sourceFile.readAsBytes();
    } on FileSystemException catch (error) {
      throw ProductImageStorageException(
        'Não foi possível ler a imagem selecionada: ${error.message}',
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const ProductImageStorageException(
        'O arquivo selecionado não contém uma imagem válida.',
      );
    }

    final oriented = img.bakeOrientation(decoded);
    return (
      _resizeToFit(oriented, maxImageDimension),
      _resizeToFit(oriented, thumbnailDimension),
    );
  }

  Future<void> _writeProcessedFiles({
    required File imageFile,
    required File thumbnailFile,
    required img.Image optimized,
    required img.Image thumbnail,
  }) async {
    try {
      await imageFile.writeAsBytes(
        img.encodeJpg(optimized, quality: imageQuality),
        flush: true,
      );
      await thumbnailFile.writeAsBytes(
        img.encodeJpg(thumbnail, quality: thumbnailQuality),
        flush: true,
      );
    } catch (error) {
      await _deleteIfExists(imageFile);
      await _deleteIfExists(thumbnailFile);
      throw ProductImageStorageException(
        'Não foi possível salvar a imagem. Verifique o espaço disponível no aparelho. ($error)',
      );
    }
  }

  Future<Directory> _temporaryRoot() async {
    final root = await _storageRoot();
    return Directory(path.join(root.path, 'temporary', 'product_images'));
  }

  Future<void> _deleteTemporaryManagedFile(String filePath) async {
    if (filePath.trim().isEmpty) return;
    final root = await _temporaryRoot();
    final normalizedRoot = path.normalize(root.absolute.path);
    final normalizedFile = path.normalize(File(filePath).absolute.path);
    if (!path.isWithin(normalizedRoot, normalizedFile)) {
      throw const ProductImageStorageException(
        'O arquivo informado não pertence à área temporária do MyShoes.',
      );
    }
    await _deleteIfExists(File(normalizedFile));
  }

  Future<void> _validateSource(File sourceFile) async {
    if (!await sourceFile.exists()) {
      throw const ProductImageStorageException(
        'A imagem selecionada não foi encontrada.',
      );
    }

    final extension = path.extension(sourceFile.path).toLowerCase();
    if (!_supportedExtensions.contains(extension)) {
      throw const ProductImageStorageException(
        'Formato não suportado. Selecione uma imagem JPG, PNG ou WebP.',
      );
    }

    final length = await sourceFile.length();
    if (length == 0) {
      throw const ProductImageStorageException(
        'A imagem selecionada está vazia.',
      );
    }
  }

  img.Image _resizeToFit(img.Image source, int maxDimension) {
    if (source.width <= maxDimension && source.height <= maxDimension) {
      return img.Image.from(source);
    }

    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: maxDimension,
        interpolation: img.Interpolation.average,
      );
    }

    return img.copyResize(
      source,
      height: maxDimension,
      interpolation: img.Interpolation.average,
    );
  }

  Future<Directory> _storageRoot() async {
    final baseDirectory = await _baseDirectoryProvider();
    return Directory(path.join(baseDirectory.path, 'myshoes'));
  }

  Future<Directory> _productDirectory(int productId) async {
    final root = await _storageRoot();
    return Directory(path.join(root.path, 'products', '$productId'));
  }

  String _uniqueName() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randomPart = List.generate(
      4,
      (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '$timestamp$randomPart';
  }

  Future<void> _deleteManagedFile(String filePath) async {
    if (filePath.trim().isEmpty) return;

    final root = await _storageRoot();
    final normalizedRoot = path.normalize(root.absolute.path);
    final normalizedFile = path.normalize(File(filePath).absolute.path);

    if (!path.isWithin(normalizedRoot, normalizedFile)) {
      throw const ProductImageStorageException(
        'O arquivo informado não pertence ao armazenamento do MyShoes.',
      );
    }

    await _deleteIfExists(File(normalizedFile));
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _deleteEmptyDirectories(Directory root) async {
    final directories = <Directory>[];
    await for (final entity in root.list(recursive: true)) {
      if (entity is Directory) directories.add(entity);
    }

    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final directory in directories) {
      if (await directory.exists() && await directory.list().isEmpty) {
        await directory.delete();
      }
    }
  }
}
