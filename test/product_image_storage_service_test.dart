import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:myshoes/services/product_image_storage_service.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temporaryDirectory;
  late ProductImageStorageService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myshoes_image_storage_test_',
    );
    service = ProductImageStorageService(
      baseDirectoryProvider: () async => temporaryDirectory,
      random: Random(42),
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  File createImage({
    required String fileName,
    required int width,
    required int height,
  }) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(120, 80, 40));
    final file = File(path.join(temporaryDirectory.path, fileName));
    file.writeAsBytesSync(img.encodePng(image));
    return file;
  }

  test('salva imagem e miniatura na estrutura interna do tênis', () async {
    final source = createImage(fileName: 'tenis.png', width: 1600, height: 900);

    final result = await service.store(productId: 15, sourceFile: source);

    expect(await File(result.imagePath).exists(), isTrue);
    expect(await File(result.thumbnailPath).exists(), isTrue);
    expect(
      path.normalize(result.imagePath),
      contains(path.normalize('myshoes/products/15/images')),
    );
    expect(
      path.normalize(result.thumbnailPath),
      contains(path.normalize('myshoes/products/15/thumbnails')),
    );
    expect(path.extension(result.imagePath), '.jpg');
  });

  test('reduz a imagem principal preservando a proporção', () async {
    final source = createImage(fileName: 'grande.png', width: 2400, height: 1200);

    final result = await service.store(productId: 1, sourceFile: source);
    final saved = img.decodeImage(await File(result.imagePath).readAsBytes());

    expect(saved, isNotNull);
    expect(saved!.width, 1200);
    expect(saved.height, 600);
  });

  test('gera miniatura com lado maior de até 300 pixels', () async {
    final source = createImage(fileName: 'vertical.png', width: 800, height: 1600);

    final result = await service.store(productId: 2, sourceFile: source);
    final thumbnail =
        img.decodeImage(await File(result.thumbnailPath).readAsBytes());

    expect(thumbnail, isNotNull);
    expect(thumbnail!.width, 150);
    expect(thumbnail.height, 300);
  });

  test('não amplia imagens menores que os limites', () async {
    final source = createImage(fileName: 'pequena.png', width: 200, height: 100);

    final result = await service.store(productId: 3, sourceFile: source);
    final saved = img.decodeImage(await File(result.imagePath).readAsBytes());
    final thumbnail =
        img.decodeImage(await File(result.thumbnailPath).readAsBytes());

    expect(saved!.width, 200);
    expect(saved.height, 100);
    expect(thumbnail!.width, 200);
    expect(thumbnail.height, 100);
  });

  test('cria nomes únicos para imagens diferentes', () async {
    final source = createImage(fileName: 'unica.png', width: 400, height: 400);

    final first = await service.store(productId: 4, sourceFile: source);
    final second = await service.store(productId: 4, sourceFile: source);

    expect(first.imagePath, isNot(second.imagePath));
    expect(first.thumbnailPath, isNot(second.thumbnailPath));
  });

  test('rejeita arquivo com formato não suportado', () async {
    final source = File(path.join(temporaryDirectory.path, 'arquivo.txt'))
      ..writeAsStringSync('não é uma imagem');

    expect(
      () => service.store(productId: 5, sourceFile: source),
      throwsA(isA<ProductImageStorageException>()),
    );
  });

  test('rejeita arquivo com extensão válida mas conteúdo inválido', () async {
    final source = File(path.join(temporaryDirectory.path, 'arquivo.jpg'))
      ..writeAsStringSync('conteúdo inválido');

    expect(
      () => service.store(productId: 6, sourceFile: source),
      throwsA(isA<ProductImageStorageException>()),
    );
  });

  test('remove a imagem e a miniatura salvas', () async {
    final source = createImage(fileName: 'remover.png', width: 500, height: 500);
    final result = await service.store(productId: 7, sourceFile: source);

    await service.remove(
      imagePath: result.imagePath,
      thumbnailPath: result.thumbnailPath,
    );

    expect(await File(result.imagePath).exists(), isFalse);
    expect(await File(result.thumbnailPath).exists(), isFalse);
  });

  test('remove todos os arquivos de um tênis', () async {
    final source = createImage(fileName: 'todos.png', width: 500, height: 500);
    final first = await service.store(productId: 8, sourceFile: source);
    final second = await service.store(productId: 8, sourceFile: source);

    await service.removeAllForProduct(8);

    expect(await File(first.imagePath).exists(), isFalse);
    expect(await File(second.thumbnailPath).exists(), isFalse);
  });

  test('remove arquivos órfãos e preserva os caminhos utilizados', () async {
    final source = createImage(fileName: 'orfaos.png', width: 500, height: 500);
    final used = await service.store(productId: 9, sourceFile: source);
    final unused = await service.store(productId: 9, sourceFile: source);

    await service.removeUnusedFiles(
      productId: 9,
      usedPaths: [used.imagePath, used.thumbnailPath],
    );

    expect(await File(used.imagePath).exists(), isTrue);
    expect(await File(used.thumbnailPath).exists(), isTrue);
    expect(await File(unused.imagePath).exists(), isFalse);
    expect(await File(unused.thumbnailPath).exists(), isFalse);
  });

  test('não deixa arquivos temporários após concluir o processamento', () async {
    final source = createImage(
      fileName: 'temporaria.png',
      width: 1800,
      height: 1200,
    );

    final result = await service.store(productId: 10, sourceFile: source);
    final productDirectory = Directory(
      path.join(temporaryDirectory.path, 'myshoes', 'products', '10'),
    );

    final storedFiles = await productDirectory
        .list(recursive: true)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();

    expect(storedFiles, hasLength(2));
    expect(
      storedFiles.map((file) => path.normalize(file.path)).toSet(),
      {
        path.normalize(result.imagePath),
        path.normalize(result.thumbnailPath),
      },
    );
    expect(
      storedFiles.any((file) {
        final name = path.basename(file.path).toLowerCase();
        return name.endsWith('.tmp') ||
            name.endsWith('.temp') ||
            name.contains('temporary');
      }),
      isFalse,
    );

    // O arquivo recebido pertence à galeria/selecionador e não deve ser
    // removido pelo serviço. Apenas arquivos intermediários internos devem
    // deixar de existir.
    expect(await source.exists(), isTrue);
  });

}
