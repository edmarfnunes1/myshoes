import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshoes/models/product.dart';
import 'package:myshoes/models/product_image.dart';
import 'package:myshoes/widgets/product_thumbnail.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('myshoes_thumbnail_test_');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Product product({List<ProductImage> images = const []}) => Product(
        id: 1,
        brand: 'Nike',
        model: 'Air Max',
        minimumSize: 34,
        maximumSize: 44,
        costPrice: 150,
        images: images,
      );

  ProductImage primaryImage(String thumbnailPath) => ProductImage(
        id: 10,
        productId: 1,
        imagePath: '${directory.path}/large.png',
        thumbnailPath: thumbnailPath,
        position: 0,
        isPrimary: true,
        createdAt: DateTime(2026, 7, 26),
      );

  Future<void> pumpThumbnail(
    WidgetTester tester,
    Product value,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductThumbnail(
            key: const ValueKey('thumbnail-under-test'),
            product: value,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mostra a miniatura principal na lista', (tester) async {
    final thumbnail = File('${directory.path}/thumb.png');
    thumbnail.writeAsBytesSync(const <int>[
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
      0, 0, 0, 13, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 240,
      31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69,
      78, 68, 174, 66, 96, 130,
    ]);

    await pumpThumbnail(
      tester,
      product(images: [primaryImage(thumbnail.path)]),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('thumbnail-under-test')),
        matching: find.byKey(const ValueKey('product-thumbnail-file')),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-thumbnail-fallback')),
      findsNothing,
    );
  });

  testWidgets('mostra o ícone atual quando não houver foto', (tester) async {
    await pumpThumbnail(tester, product());

    expect(
      find.byKey(const ValueKey('product-thumbnail-fallback')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-thumbnail-file')),
      findsNothing,
    );
  });

  testWidgets('usa o ícone como fallback quando o arquivo não existe',
      (tester) async {
    final missingPath = '${directory.path}/arquivo-ausente.png';

    await pumpThumbnail(
      tester,
      product(images: [primaryImage(missingPath)]),
    );

    // O erro do FileImage é processado em frames posteriores.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('product-thumbnail-fallback')),
      findsOneWidget,
    );
  });
}
