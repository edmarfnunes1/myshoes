import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:myshoes/services/product_image_selection_service.dart';
import 'package:myshoes/services/product_image_storage_service.dart';

void main() {
  late Directory root;
  late ProductImageStorageService storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('myshoes_selection_test_');
    storage = ProductImageStorageService(
      baseDirectoryProvider: () async => root,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> createImage(String name) async {
    final file = File('${root.path}/$name.jpg');
    await file.writeAsBytes(img.encodeJpg(img.Image(width: 640, height: 480)));
    return file;
  }

  test('cancelamento retorna lista vazia sem erro', () async {
    final service = ProductImageSelectionService(
      storageService: storage,
      pickImages: (_) async => const [],
    );

    final result = await service.selectAndPrepare(availableSlots: 3);

    expect(result.cancelled, isTrue);
    expect(result.images, isEmpty);
  });

  test('prepara várias imagens na ordem selecionada', () async {
    final first = await createImage('primeira');
    final second = await createImage('segunda');
    final service = ProductImageSelectionService(
      storageService: storage,
      pickImages: (_) async => [XFile(first.path), XFile(second.path)],
    );

    final result = await service.selectAndPrepare(availableSlots: 2);

    expect(result.images, hasLength(2));
    for (final files in result.images) {
      expect(await File(files.imagePath).exists(), isTrue);
      expect(await File(files.thumbnailPath).exists(), isTrue);
      expect(files.imagePath, contains('temporary'));
    }
  });

  test('rejeita seleção acima da quantidade disponível', () async {
    final files = <XFile>[];
    for (var index = 0; index < 3; index++) {
      files.add(XFile((await createImage('foto_$index')).path));
    }
    final service = ProductImageSelectionService(
      storageService: storage,
      pickImages: (_) async => files,
    );

    expect(
      () => service.selectAndPrepare(availableSlots: 2),
      throwsA(isA<ProductImageStorageException>()),
    );
  });

  test('remove temporários já preparados quando outra imagem falha', () async {
    final valid = await createImage('valida');
    final invalid = File('${root.path}/invalida.txt')..writeAsStringSync('x');
    final service = ProductImageSelectionService(
      storageService: storage,
      pickImages: (_) async => [XFile(valid.path), XFile(invalid.path)],
    );

    await expectLater(
      service.selectAndPrepare(availableSlots: 2),
      throwsA(isA<ProductImageStorageException>()),
    );

    final temporaryRoot = Directory(
      '${root.path}/myshoes/temporary/product_images',
    );
    if (await temporaryRoot.exists()) {
      expect(await temporaryRoot.list(recursive: true).where((e) => e is File).isEmpty, isTrue);
    }
  });

  test('bloqueia seleção quando não há vagas disponíveis', () async {
    final service = ProductImageSelectionService(
      storageService: storage,
      pickImages: (_) async => throw StateError('não deve abrir a galeria'),
    );

    expect(
      () => service.selectAndPrepare(availableSlots: 0),
      throwsA(isA<ProductImageStorageException>()),
    );
  });
}
