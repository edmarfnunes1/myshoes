import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshoes/data/order_repository.dart';
import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';
import 'package:myshoes/models/product.dart';
import 'package:myshoes/pages/orders/order_form_page.dart';

class FakeOrderRepository extends OrderRepository {
  FakeOrderRepository({this.orderToLoad, this.throwOnSave = false});

  final Order? orderToLoad;
  final bool throwOnSave;
  Order? savedOrder;

  @override
  Future<Order?> findById(int id) async => orderToLoad;

  @override
  Future<void> save(Order order) async {
    if (throwOnSave) throw Exception('falha ao salvar');
    savedOrder = order;
  }
}

class FakeProductRepository extends ProductRepository {
  FakeProductRepository({this.products = const []});

  final List<Product> products;

  @override
  Future<List<Product>> findAll({String search = ''}) async => products;
}

void main() {
  const product = Product(
    id: 1,
    brand: 'Nike',
    model: 'Air Max',
    minimumSize: 38,
    maximumSize: 40,
    costPrice: 200,
    salePrice: 350,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    FakeOrderRepository? orderRepository,
    FakeProductRepository? productRepository,
    Order? order,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderFormPage(
          order: order,
          orderRepository: orderRepository ?? FakeOrderRepository(),
          productRepository:
              productRepository ?? FakeProductRepository(products: [product]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addProduct(WidgetTester tester) async {
    await tester.tap(find.text('Adicionar produto'));
    await tester.pumpAndSettle();

    expect(find.text('Selecionar produto'), findsOneWidget);
    await tester.tap(find.text('Nike Air Max'));
    await tester.pump();
    await tester.tap(find.text('Selecionar'));
    await tester.pumpAndSettle();

    expect(find.text('Configurar produto'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('39').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
  }

  group('OrderFormPage - estado inicial', () {
    testWidgets('exibe os campos principais do lançamento', (tester) async {
      await pumpPage(tester);

      expect(find.text('Novo pedido'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Itens do pedido'), findsOneWidget);
      expect(find.text('Nenhum produto adicionado.'), findsOneWidget);
      expect(find.text('Situação do pagamento'), findsWidgets);
      expect(find.text('Salvar pedido'), findsOneWidget);
    });

    testWidgets('desabilita adicionar produto quando não há cadastro',
        (tester) async {
      await pumpPage(
        tester,
        productRepository: FakeProductRepository(),
      );

      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Adicionar produto'),
          matching: find.byType(OutlinedButton),
        ),
      );

      expect(button.onPressed, isNull);
      expect(
        find.text('Cadastre um produto antes de lançar o pedido.'),
        findsOneWidget,
      );
    });
  });

  group('OrderFormPage - validações', () {
    testWidgets('valida nome obrigatório ao salvar vazio', (tester) async {
      await pumpPage(tester);

      await tester.ensureVisible(find.text('Salvar pedido'));
      await tester.tap(find.text('Salvar pedido'));
      await tester.pump();

      expect(find.text('Informe o nome do cliente.'), findsOneWidget);
    });

    testWidgets('exige ao menos um produto', (tester) async {
      await pumpPage(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome *'),
        'João Silva',
      );
      await tester.ensureVisible(find.text('Salvar pedido'));
      await tester.tap(find.text('Salvar pedido'));
      await tester.pump();

      expect(find.text('Adicione pelo menos um produto.'), findsOneWidget);
    });

    testWidgets('valida numeração na configuração do produto', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Adicionar produto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nike Air Max'));
      await tester.pump();
      await tester.tap(find.text('Selecionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar'));
      await tester.pump();

      expect(find.text('Selecione a numeração.'), findsOneWidget);
    });
  });

  group('OrderFormPage - itens e salvamento', () {
    testWidgets('adiciona produto e calcula o total', (tester) async {
      await pumpPage(tester);
      await addProduct(tester);

      expect(find.text('Nike Air Max'), findsOneWidget);
      expect(find.text('Nº 39'), findsOneWidget);
      expect(find.text('Qtd. 1'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('Total do pedido'), findsOneWidget);
      expect(find.text('R\$ 350,00'), findsWidgets);
    });

    testWidgets('salva lançamento com cliente, item e observações',
        (tester) async {
      final repository = FakeOrderRepository();
      await pumpPage(tester, orderRepository: repository);
      await addProduct(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome *'),
        '  Maria Souza  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefone'),
        '  (44) 99999-0000  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Observações'),
        '  Entregar à tarde  ',
      );

      await tester.ensureVisible(find.text('Salvar pedido'));
      await tester.tap(find.text('Salvar pedido'));
      await tester.pumpAndSettle();

      expect(repository.savedOrder, isNotNull);
      expect(repository.savedOrder?.customerName, 'Maria Souza');
      expect(repository.savedOrder?.customerPhone, '(44) 99999-0000');
      expect(repository.savedOrder?.notes, 'Entregar à tarde');
      expect(repository.savedOrder?.items, hasLength(1));
      expect(repository.savedOrder?.items.first.productId, 1);
      expect(repository.savedOrder?.items.first.shoeSize, 39);
      expect(repository.savedOrder?.items.first.unitPrice, 350);
    });

    testWidgets('exibe erro quando o repositório falha ao salvar',
        (tester) async {
      final repository = FakeOrderRepository(throwOnSave: true);
      await pumpPage(tester, orderRepository: repository);
      await addProduct(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome *'),
        'Cliente Teste',
      );

      await tester.ensureVisible(find.text('Salvar pedido'));
      await tester.tap(find.text('Salvar pedido'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível salvar o pedido.'), findsOneWidget);
    });

    testWidgets('carrega os dados ao editar um lançamento', (tester) async {
      final order = Order(
        id: 10,
        customerName: 'Carlos Lima',
        customerPhone: '44999990000',
        paymentStatus: 'Pago',
        notes: 'Cliente recorrente',
        createdAt: DateTime(2026, 7, 23),
        items: const [
          OrderItem(
            id: 5,
            orderId: 10,
            productId: 1,
            shoeSize: 40,
            quantity: 2,
            withBox: true,
            unitPrice: 300,
            productName: 'Nike Air Max',
          ),
        ],
      );
      final repository = FakeOrderRepository(orderToLoad: order);

      await pumpPage(
        tester,
        order: order,
        orderRepository: repository,
      );

      expect(find.text('Editar pedido'), findsOneWidget);
      expect(find.text('Carlos Lima'), findsOneWidget);
      expect(find.text('44999990000'), findsOneWidget);
      expect(find.text('Cliente recorrente'), findsOneWidget);
      expect(find.text('Nike Air Max'), findsOneWidget);
      expect(find.text('Nº 40'), findsOneWidget);
      expect(find.text('Qtd. 2'), findsOneWidget);
      expect(find.text('Com caixa'), findsOneWidget);
    });
  });
}
