import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshoes/widgets/product_gallery_viewer.dart';

void main() {
  late Directory directory;
  late List<String> imagePaths;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('myshoes_gallery_test_');
    imagePaths = List.generate(3, (index) {
      final file = File('${directory.path}/image_$index.png');
      file.writeAsBytesSync(const <int>[
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
        0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
        0, 0, 0, 13, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 240,
        31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69,
        78, 68, 174, 66, 96, 130,
      ]);
      return file.path;
    });
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<void> openGallery(
    WidgetTester tester, {
    required List<String> paths,
    int initialIndex = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ProductGalleryViewer(
                  imagePaths: paths,
                  initialIndex: initialIndex,
                ),
              ),
              child: const Text('Abrir galeria'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir galeria'));
    await tester.pumpAndSettle();
  }

  testWidgets('abre na posição correta', (tester) async {
    await openGallery(tester, paths: imagePaths, initialIndex: 1);

    expect(find.text('2/3'), findsOneWidget);
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('product-gallery-page-view')),
    );
    expect(pageView.controller?.initialPage, 1);
  });

  testWidgets('navega entre as fotos', (tester) async {
    await openGallery(tester, paths: imagePaths);

    await tester.drag(
      find.byKey(const ValueKey('product-gallery-page-view')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('product-gallery-page-view')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('exibe o contador da foto atual', (tester) async {
    await openGallery(tester, paths: imagePaths, initialIndex: 2);

    expect(
      find.byKey(const ValueKey('product-gallery-counter')),
      findsOneWidget,
    );
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('funciona com apenas uma foto', (tester) async {
    await openGallery(tester, paths: [imagePaths.first]);

    expect(find.text('1/1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-gallery-image-0')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('product-gallery-page-view')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('fecha corretamente', (tester) async {
    await openGallery(tester, paths: imagePaths);

    await tester.tap(find.byKey(const ValueKey('product-gallery-close')));
    await tester.pumpAndSettle();

    expect(find.byType(ProductGalleryViewer), findsNothing);
    expect(find.text('Abrir galeria'), findsOneWidget);
  });
}
