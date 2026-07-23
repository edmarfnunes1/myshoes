import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/product.dart';
import 'package:myshoes/screens/product_form_screen.dart';

class FakeProductRepository extends ProductRepository {
  FakeProductRepository({this.brands = const []});

  final List<String> brands;
  Product? savedProduct;

  @override
  Future<List<String>> findBrands() async => brands;

  @override
  Future<Product> save(Product product) async {
    savedProduct = product;
    return product.copyWith(id: product.id ?? 1);
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    FakeProductRepository? repository,
    Product? product,
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

      await tester.ensureVisible(find.text('Salvar produto'));
      await tester.tap(find.text('Salvar produto'));
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
      await tester.ensureVisible(find.text('Salvar produto'));
      await tester.tap(find.text('Salvar produto'));
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

      await tester.ensureVisible(find.text('Salvar produto'));
      await tester.tap(find.text('Salvar produto'));
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

      expect(find.text('Editar produto'), findsOneWidget);
      expect(find.text('Lacoste'), findsWidgets);
      expect(find.text('L003'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
      expect(find.text('43'), findsOneWidget);
      expect(find.text('Linha premium'), findsOneWidget);
    });
  });
}
