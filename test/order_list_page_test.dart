import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshoes/data/order_repository.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';
import 'package:myshoes/pages/orders/order_list_page.dart';

class FakeOrderRepository extends OrderRepository {
  FakeOrderRepository({this.orders = const []});

  List<Order> orders;
  final List<String> searches = [];
  int? deletedId;

  @override
  Future<List<Order>> findAll({String search = ''}) async {
    searches.add(search);
    final normalized = search.trim().toLowerCase();
    if (normalized.isEmpty) return orders;
    return orders
        .where(
          (order) => order.customerName.toLowerCase().contains(normalized),
        )
        .toList();
  }

  @override
  Future<void> delete(int id) async {
    deletedId = id;
    orders = orders.where((order) => order.id != id).toList();
  }
}

void main() {
  Order sampleOrder({int id = 1, String customerName = 'Ana Paula'}) => Order(
        id: id,
        customerName: customerName,
        customerPhone: '44999990000',
        paymentStatus: 'Pendente',
        notes: 'Entregar no centro',
        createdAt: DateTime(2026, 7, 23),
        items: const [
          OrderItem(
            productId: 1,
            shoeSize: 38,
            quantity: 2,
            withBox: false,
            unitPrice: 150,
            productName: 'Nike Air Max',
          ),
        ],
      );

  Future<void> pumpPage(
    WidgetTester tester, {
    required FakeOrderRepository repository,
    Widget Function(Order? order)? formPageBuilder,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderListPage(
          repository: repository,
          formPageBuilder: formPageBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exibe estado vazio e ações para cadastrar', (tester) async {
    await pumpPage(tester, repository: FakeOrderRepository());

    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Nenhum pedido cadastrado.'), findsOneWidget);
    expect(find.text('Cadastrar pedido'), findsOneWidget);
    expect(find.text('Novo pedido'), findsOneWidget);
  });

  testWidgets('exibe dados resumidos do lançamento', (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(orders: [sampleOrder()]),
    );

    expect(find.text('Ana Paula'), findsOneWidget);
    expect(find.text('44999990000'), findsOneWidget);
    expect(find.text('Nike Air Max • Nº 38 • Qtd. 2'), findsOneWidget);
    expect(find.text('2 produto(s)'), findsOneWidget);
    expect(find.text('R\$ 300,00'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.text('Entregar no centro'), findsOneWidget);
  });

  testWidgets('filtra pedidos após digitar na busca', (tester) async {
    final repository = FakeOrderRepository(
      orders: [
        sampleOrder(customerName: 'Ana Paula'),
        sampleOrder(id: 2, customerName: 'Bruno Souza'),
      ],
    );
    await pumpPage(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'Bruno');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.searches, contains('Bruno'));
    expect(find.text('Bruno Souza'), findsOneWidget);
    expect(find.text('Ana Paula'), findsNothing);
  });

  testWidgets('exibe estado de busca sem resultado', (tester) async {
    final repository = FakeOrderRepository(orders: [sampleOrder()]);
    await pumpPage(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'Inexistente');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum pedido encontrado.'), findsOneWidget);
    expect(find.text('Cadastrar pedido'), findsNothing);
  });

  testWidgets('abre formulário de novo lançamento pelo botão', (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(),
      formPageBuilder: (_) => const Scaffold(
        body: Center(child: Text('Formulário fake')),
      ),
    );

    await tester.tap(find.text('Novo pedido'));
    await tester.pumpAndSettle();

    expect(find.text('Formulário fake'), findsOneWidget);
  });

  testWidgets('exclui lançamento após confirmação', (tester) async {
    final repository = FakeOrderRepository(orders: [sampleOrder()]);
    await pumpPage(tester, repository: repository);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir pedido?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(repository.deletedId, 1);
    expect(find.text('Nenhum pedido cadastrado.'), findsOneWidget);
  });
}
