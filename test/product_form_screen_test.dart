import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/product.dart';
import 'package:myshoes/models/product_image.dart';
import 'package:myshoes/services/product_image_selection_service.dart';
import 'package:myshoes/services/product_image_storage_service.dart';
import 'package:myshoes/screens/product_form_screen.dart';

class FakeProductRepository extends ProductRepository {
  FakeProductRepository({
    this.brands = const [],
    this.images = const [],
  });

  final List<String> brands;
  final List<ProductImage> images;
  Product? savedProduct;
  int saveCalls = 0;
  int gallerySaveCalls = 0;
  int? savedGalleryProductId;
  List<int?>? savedOrderedImageIds;
  List<TemporaryProductImageFiles>? savedTemporaryImages;
  int? savedPrimaryIndex;

  @override
  Future<List<String>> findBrands() async => brands;

  @override
  Future<List<ProductImage>> getImagesByProductId(int productId) async => images;

  @override
  Future<Product> save(Product product) async {
    saveCalls++;
    savedProduct = product;
    return product.copyWith(id: product.id ?? 1);
  }

  @override
  Future<List<ProductImage>> saveImageGallery({
    required int productId,
    required List<int?> orderedImageIds,
    required List<TemporaryProductImageFiles> temporaryImages,
    required int primaryIndex,
  }) async {
    gallerySaveCalls++;
    savedGalleryProductId = productId;
    savedOrderedImageIds = List<int?>.from(orderedImageIds);
    savedTemporaryImages = List<TemporaryProductImageFiles>.from(temporaryImages);
    savedPrimaryIndex = primaryIndex;
    return const [];
  }
}

class FakeProductImageSelectionService extends ProductImageSelectionService {
  FakeProductImageSelectionService(this.results)
      : super(storageService: FakeProductImageStorageService());

  final List<ProductImageSelectionResult> results;
  final List<int> requestedLimits = [];
  int _index = 0;

  @override
  Future<ProductImageSelectionResult> selectAndPrepare({
    required int availableSlots,
  }) async {
    requestedLimits.add(availableSlots);
    if (_index >= results.length) {
      return const ProductImageSelectionResult(images: [], cancelled: true);
    }
    return results[_index++];
  }
}

class FakeProductImageStorageService extends ProductImageStorageService {
  final List<TemporaryProductImageFiles> removedTemporary = [];

  @override
  Future<void> removeTemporary(TemporaryProductImageFiles files) async {
    removedTemporary.add(files);
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    FakeProductRepository? repository,
    Product? product,
    ProductImageSelectionService? imageSelectionService,
    ProductImageStorageService? imageStorageService,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductFormScreen(
          product: product,
          repository: repository ?? FakeProductRepository(),
          imageSelectionService: imageSelectionService,
          imageStorageService: imageStorageService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ProductFormScreen - marcas', () {
    testWidgets('exibe todos os chips de marcas rápidas', (tester) async {
      await pumpScreen(tester);

      for (final brand in [
        'Nike',
        'Adidas',
        'Puma',
        'New Balance',
        'Vans',
        'Lacoste',
        'Oakley',
      ]) {
        expect(find.widgetWithText(ChoiceChip, brand), findsOneWidget);
      }
      expect(find.widgetWithText(ActionChip, 'Outra'), findsOneWidget);
    });

    testWidgets('preenche o campo ao selecionar um chip', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'New Balance'));
      await tester.pump();

      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Marca *'),
      );
      expect(field.controller?.text, 'New Balance');

      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'New Balance'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('autocomplete sugere Oakley ao digitar Oa', (tester) async {
      final repository = FakeProductRepository(brands: ['Fila']);
      await pumpScreen(tester, repository: repository);

      final brandField = find.widgetWithText(TextFormField, 'Marca *');
      await tester.tap(brandField);
      await tester.enterText(brandField, 'Oa');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Oakley'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Fila'), findsNothing);
    });

    testWidgets('inclui marcas já cadastradas no autocomplete', (tester) async {
      final repository = FakeProductRepository(brands: ['Fila']);
      await pumpScreen(tester, repository: repository);

      final brandField = find.widgetWithText(TextFormField, 'Marca *');
      await tester.tap(brandField);
      await tester.enterText(brandField, 'Fil');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Fila'), findsOneWidget);
    });

    testWidgets('botão Outra limpa a marca e mantém o campo em foco',
        (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Nike'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ActionChip, 'Outra'));
      await tester.pump();

      final brandField = find.widgetWithText(TextFormField, 'Marca *');
      final field = tester.widget<TextFormField>(brandField);
      final editableText = tester.widget<EditableText>(
        find.descendant(of: brandField, matching: find.byType(EditableText)),
      );

      expect(field.controller?.text, isEmpty);
      expect(editableText.focusNode.hasFocus, isTrue);
    });
  });

  group('ProductFormScreen - formulário', () {
    testWidgets('exibe validações ao tentar salvar vazio', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text('Salvar tênis'));
      await tester.tap(find.text('Salvar tênis'));
      await tester.pump();

      expect(find.text('Informe a marca.'), findsOneWidget);
      expect(find.text('Informe o modelo.'), findsOneWidget);
      expect(find.text('Informe a numeração mínima.'), findsOneWidget);
      expect(find.text('Informe a numeração máxima.'), findsOneWidget);
      expect(find.text('Informe o valor de custo.'), findsOneWidget);
    });

    testWidgets('valida numeração máxima menor que a mínima', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numeração mínima *'),
        '40',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numeração máxima *'),
        '38',
      );
      await tester.ensureVisible(find.text('Salvar tênis'));
      await tester.tap(find.text('Salvar tênis'));
      await tester.pump();

      expect(
        find.text('A numeração máxima deve ser igual ou maior que a mínima.'),
        findsOneWidget,
      );
    });

    testWidgets('salva produto preenchido e retorna true', (tester) async {
      final repository = FakeProductRepository();
      await pumpScreen(tester, repository: repository);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Vans'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Modelo *'),
        'Old Skool',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numeração mínima *'),
        '34',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numeração máxima *'),
        '39',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor de custo *'),
        '15000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor de venda'),
        '22990',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Observações'),
        'Modelo clássico',
      );

      await tester.ensureVisible(find.text('Salvar tênis'));
      await tester.tap(find.text('Salvar tênis'));
      await tester.pumpAndSettle();

      expect(repository.savedProduct, isNotNull);
      expect(repository.savedProduct?.brand, 'Vans');
      expect(repository.savedProduct?.model, 'Old Skool');
      expect(repository.savedProduct?.minimumSize, 34);
      expect(repository.savedProduct?.maximumSize, 39);
      expect(repository.savedProduct?.costPrice, 150);
      expect(repository.savedProduct?.salePrice, 229.90);
      expect(repository.savedProduct?.notes, 'Modelo clássico');
    });

    testWidgets('carrega os dados ao editar um produto', (tester) async {
      const product = Product(
        id: 10,
        brand: 'Lacoste',
        model: 'L003',
        minimumSize: 38,
        maximumSize: 43,
        costPrice: 180,
        salePrice: 299.90,
        notes: 'Linha premium',
      );

      await pumpScreen(tester, product: product);

      expect(find.text('Editar tênis'), findsOneWidget);
      expect(find.text('Lacoste'), findsWidgets);
      expect(find.text('L003'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
      expect(find.text('43'), findsOneWidget);
      expect(find.text('Linha premium'), findsOneWidget);
    });
  });

  group('ProductFormScreen - galeria de fotos', () {
    late Directory imageDirectory;
    late int imageSequence;

    setUp(() async {
      imageDirectory = await Directory.systemTemp.createTemp(
        'myshoes_product_form_images_',
      );
      imageSequence = 0;
    });

    tearDown(() async {
      if (await imageDirectory.exists()) {
        await imageDirectory.delete(recursive: true);
      }
    });

    TemporaryProductImageFiles createTemporaryImage() {
      final index = imageSequence++;
      final image = File('${imageDirectory.path}/image_$index.png');
      final thumbnail = File('${imageDirectory.path}/thumb_$index.png');
      // PNG 1x1 transparente válido, suficiente para Image.file nos testes.
      const png = <int>[
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
        0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
        0, 0, 0, 13, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 240,
        31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69,
        78, 68, 174, 66, 96, 130,
      ];
      image.writeAsBytesSync(png);
      thumbnail.writeAsBytesSync(png);
      return TemporaryProductImageFiles(
        imagePath: image.path,
        thumbnailPath: thumbnail.path,
      );
    }

    ProductImage createExistingImage({
      required int id,
      required int position,
      required bool isPrimary,
    }) {
      final path = '${imageDirectory.path}/existing_$id.png';
      File(path).writeAsBytesSync(const <int>[
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
        0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
        0, 0, 0, 13, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 240,
        31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69,
        78, 68, 174, 66, 96, 130,
      ]);
      return ProductImage(
        id: id,
        productId: 10,
        imagePath: path,
        thumbnailPath: path,
        position: position,
        isPrimary: isPrimary,
        createdAt: DateTime(2026, 7, 26),
      );
    }

    const editableProduct = Product(
      id: 10,
      brand: 'DC Shoes',
      model: 'Court Graffik',
      minimumSize: 34,
      maximumSize: 44,
      costPrice: 180,
    );

    Future<void> saveForm(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Salvar tênis'));
      await tester.tap(find.text('Salvar tênis'));
      await tester.pumpAndSettle();
    }

    testWidgets('seleciona uma imagem e a define como principal', (tester) async {
      final image = createTemporaryImage();
      final selection = FakeProductImageSelectionService([
        ProductImageSelectionResult(images: [image]),
      ]);

      await pumpScreen(tester, imageSelectionService: selection);
      await tester.tap(find.text('Adicionar fotos'));
      // Evita pumpAndSettle aqui: Image.file pode manter frames pendentes
      // durante a decodificação do thumbnail e fazer o teste aguardar indefinidamente.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(selection.requestedLimits, [5]);
      expect(find.text('1/5'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);
      expect(find.text('Você pode selecionar mais 4 foto(s).'), findsOneWidget);
    });

    testWidgets('seleciona várias imagens de uma vez', (tester) async {
      final images = [
        createTemporaryImage(),
        createTemporaryImage(),
        createTemporaryImage(),
      ];
      final selection = FakeProductImageSelectionService([
        ProductImageSelectionResult(images: images),
      ]);

      await pumpScreen(tester, imageSelectionService: selection);
      await tester.tap(find.text('Adicionar fotos'));
      await tester.pumpAndSettle();

      expect(selection.requestedLimits, [5]);
      expect(find.text('3/5'), findsOneWidget);
      expect(find.byTooltip('Ações da foto'), findsNWidgets(3));
      expect(find.text('Principal'), findsOneWidget);
    });

    testWidgets('limita a galeria em cinco imagens', (tester) async {
      final images = <TemporaryProductImageFiles>[];
      for (var index = 0; index < 5; index++) {
        images.add(createTemporaryImage());
      }
      final selection = FakeProductImageSelectionService([
        ProductImageSelectionResult(images: images),
      ]);

      await pumpScreen(tester, imageSelectionService: selection);
      await tester.tap(find.text('Adicionar fotos'));
      await tester.pumpAndSettle();

      expect(find.text('5/5'), findsOneWidget);
      expect(find.text('Limite de 5 fotos atingido.'), findsOneWidget);
      final addButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Adicionar fotos'),
      );
      expect(addButton.onPressed, isNull);
      expect(selection.requestedLimits, [5]);
    });

    testWidgets('remove uma imagem e libera uma vaga', (tester) async {
      final first = createTemporaryImage();
      final second = createTemporaryImage();
      final storage = FakeProductImageStorageService();
      final selection = FakeProductImageSelectionService([
        ProductImageSelectionResult(images: [first, second]),
      ]);

      await pumpScreen(
        tester,
        imageSelectionService: selection,
        imageStorageService: storage,
      );
      await tester.tap(find.text('Adicionar fotos'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ações da foto').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();

      expect(find.text('1/5'), findsOneWidget);
      expect(find.text('Você pode selecionar mais 4 foto(s).'), findsOneWidget);
      expect(storage.removedTemporary, [second]);
    });

    testWidgets('muda a imagem principal', (tester) async {
      final repository = FakeProductRepository(images: [
        createExistingImage(id: 11, position: 0, isPrimary: true),
        createExistingImage(id: 22, position: 1, isPrimary: false),
      ]);

      await pumpScreen(tester, repository: repository, product: editableProduct);
      await tester.tap(find.byTooltip('Ações da foto').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Definir como principal'));
      await tester.pumpAndSettle();

      expect(find.text('Principal'), findsOneWidget);
      await saveForm(tester);
      expect(repository.savedPrimaryIndex, 1);
    });

    testWidgets('altera a ordem das imagens antes de salvar', (tester) async {
      final repository = FakeProductRepository(images: [
        createExistingImage(id: 11, position: 0, isPrimary: true),
        createExistingImage(id: 22, position: 1, isPrimary: false),
        createExistingImage(id: 33, position: 2, isPrimary: false),
      ]);

      await pumpScreen(tester, repository: repository, product: editableProduct);
      await tester.tap(find.byTooltip('Mover para direita').at(0));
      await tester.pump();
      await saveForm(tester);

      expect(repository.savedOrderedImageIds, [22, 11, 33]);
      expect(repository.savedPrimaryIndex, 1);
    });

    testWidgets('salva o tênis com as imagens selecionadas', (tester) async {
      final repository = FakeProductRepository();
      final first = createTemporaryImage();
      final second = createTemporaryImage();
      final selection = FakeProductImageSelectionService([
        ProductImageSelectionResult(images: [first, second]),
      ]);

      await pumpScreen(
        tester,
        repository: repository,
        imageSelectionService: selection,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'DC Shoes'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Modelo *'),
        'Court Graffik',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numeração mínima *'),
        '34',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numeração máxima *'),
        '44',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor de custo *'),
        '18000',
      );
      await tester.tap(find.text('Adicionar fotos'));
      await tester.pumpAndSettle();
      await saveForm(tester);

      expect(repository.saveCalls, 1);
      expect(repository.gallerySaveCalls, 1);
      expect(repository.savedGalleryProductId, 1);
      expect(repository.savedOrderedImageIds, [null, null]);
      expect(repository.savedTemporaryImages, [first, second]);
      expect(repository.savedPrimaryIndex, 0);
    });

    testWidgets('cancela sem salvar alterações e remove temporários', (tester) async {
      final repository = FakeProductRepository();
      final temporary = createTemporaryImage();
      final storage = FakeProductImageStorageService();
      final selection = FakeProductImageSelectionService([
        ProductImageSelectionResult(images: [temporary]),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ProductFormScreen(
                        repository: repository,
                        imageSelectionService: selection,
                        imageStorageService: storage,
                      ),
                    ),
                  ),
                  child: const Text('Abrir formulário'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir formulário'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Abrir formulário'), findsOneWidget);
      expect(repository.saveCalls, 0);
      expect(repository.gallerySaveCalls, 0);
      expect(storage.removedTemporary, [temporary]);
    });

    testWidgets('edita tênis antigo sem imagens', (tester) async {
      final repository = FakeProductRepository(images: const []);

      await pumpScreen(tester, repository: repository, product: editableProduct);

      expect(find.text('Editar tênis'), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);
      expect(find.text('Você pode selecionar mais 5 foto(s).'), findsOneWidget);
      expect(find.text('DC Shoes'), findsWidgets);
      expect(find.text('Court Graffik'), findsOneWidget);

      await saveForm(tester);

      expect(repository.saveCalls, 1);
      expect(repository.gallerySaveCalls, 1);
      expect(repository.savedOrderedImageIds, isEmpty);
      expect(repository.savedTemporaryImages, isEmpty);
      expect(repository.savedPrimaryIndex, -1);
    });
  });

}
