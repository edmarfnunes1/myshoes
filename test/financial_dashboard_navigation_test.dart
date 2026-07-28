import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/order_repository.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';
import 'package:myshoes/pages/financial/financial_dashboard_page.dart';

class FakeFinancialOrderRepository extends OrderRepository {
  FakeFinancialOrderRepository(this.orders);

  List<Order> orders;
  int findAllCalls = 0;

  @override
  Future<List<Order>> findAll({String search = ''}) async {
    findAllCalls++;
    return List<Order>.from(orders);
  }
}

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required FakeFinancialOrderRepository repository,
    required Widget Function(Order order) formPageBuilder,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: FinancialDashboardPage(
          repository: repository,
          formPageBuilder: formPageBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('abre pedido normal mantendo edição normal', (tester) async {
    final order = _order(id: 10, status: 'Pendente');
    final repository = FakeFinancialOrderRepository([order]);
    Order? openedOrder;

    await pumpDashboard(
      tester,
      repository: repository,
      formPageBuilder: (selectedOrder) {
        openedOrder = selectedOrder;
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.pop(tester.element(find.byType(TextButton)), false),
              child: const Text('Fechar pedido'),
            ),
          ),
        );
      },
    );

    await tester.tap(find.byKey(const ValueKey('financial-order-10')));
    await tester.pumpAndSettle();

    expect(openedOrder?.id, 10);
    expect(openedOrder?.isInProductionBatch, isFalse);
    expect(find.text('Fechar pedido'), findsOneWidget);
  });

  testWidgets('abre pedido em produção no fluxo de atualização de pagamento',
      (tester) async {
    final order = _order(
      id: 20,
      status: 'Parcial',
      amountPaid: 40,
      productionBatchId: 3,
    );
    final repository = FakeFinancialOrderRepository([order]);
    Order? openedOrder;

    await pumpDashboard(
      tester,
      repository: repository,
      formPageBuilder: (selectedOrder) {
        openedOrder = selectedOrder;
        return const Scaffold(body: Center(child: Text('Atualizar pagamento')));
      },
    );

    await tester.tap(find.byKey(const ValueKey('financial-order-20')));
    await tester.pumpAndSettle();

    expect(openedOrder?.isInProductionBatch, isTrue);
    expect(find.text('Atualizar pagamento'), findsOneWidget);
  });

  testWidgets('recarrega automaticamente os indicadores e a lista após salvar',
      (tester) async {
    final original = _order(
      id: 30,
      status: 'Parcial',
      amountPaid: 40,
      productionBatchId: 7,
    );
    final repository = FakeFinancialOrderRepository([original]);

    await pumpDashboard(
      tester,
      repository: repository,
      formPageBuilder: (selectedOrder) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () {
              repository.orders = [
                _order(
                  id: 30,
                  status: 'Pago',
                  amountPaid: 100,
                  productionBatchId: 7,
                ),
              ];
              Navigator.pop(tester.element(find.byType(FilledButton)), true);
            },
            child: const Text('Salvar pagamento'),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('financial-summary-value-recebido')),
      ).data,
      'R\$ 40,00',
    );
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('financial-status-parcial-count')),
      ).data,
      '1',
    );
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('financial-summary-value-custo-total')),
      ).data,
      'R\$ 65,00',
    );

    await tester.tap(find.byKey(const ValueKey('financial-order-30')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar pagamento'));
    await tester.pumpAndSettle();

    expect(repository.findAllCalls, 2);
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('financial-summary-value-recebido')),
      ).data,
      'R\$ 100,00',
    );
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('financial-summary-value-pendente')),
      ).data,
      'R\$ 0,00',
    );
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('financial-status-pago-count')),
      ).data,
      '1',
    );
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('financial-status-parcial-count')),
      ).data,
      '0',
    );
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('financial-summary-value-custo-total')),
      ).data,
      'R\$ 65,00',
    );
    expect(find.text('Pagamento atualizado com sucesso.'), findsOneWidget);
  });
}

Order _order({
  required int id,
  required String status,
  double amountPaid = 0,
  int? productionBatchId,
}) {
  final now = DateTime.now();
  return Order(
    id: id,
    customerName: 'Cliente $id',
    paymentStatus: status,
    amountPaid: amountPaid,
    productionBatchId: productionBatchId,
    createdAt: DateTime(now.year, now.month, now.day),
    items: const [
      OrderItem(
        productId: 1,
        productName: 'Nike Air Max',
        shoeSize: 40,
        quantity: 1,
        unitPrice: 100,
        costPriceUnit: 60,
        boxFeeUnit: 5,
        withBox: true,
      ),
    ],
  );
}
