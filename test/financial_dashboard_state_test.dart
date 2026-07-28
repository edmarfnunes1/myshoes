import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/order_repository.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';
import 'package:myshoes/pages/financial/financial_dashboard_page.dart';

class ControlledFinancialRepository extends OrderRepository {
  ControlledFinancialRepository({
    List<Order>? orders,
    this.error,
    this.completer,
  }) : orders = orders ?? <Order>[];

  List<Order> orders;
  Object? error;
  Completer<List<Order>>? completer;
  int findAllCalls = 0;

  @override
  Future<List<Order>> findAll({String search = ''}) async {
    findAllCalls++;
    final pending = completer;
    if (pending != null) return pending.future;
    final failure = error;
    if (failure != null) throw failure;
    return List<Order>.from(orders);
  }
}

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester,
    ControlledFinancialRepository repository, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: FinancialDashboardPage(repository: repository),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('exibe estado de carregamento enquanto consulta os pedidos',
      (tester) async {
    final completer = Completer<List<Order>>();
    final repository = ControlledFinancialRepository(completer: completer);

    await pumpDashboard(tester, repository, settle: false);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('financial-loading-state')),
      findsOneWidget,
    );

    completer.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('exibe mensagem quando não há pedidos no período selecionado',
      (tester) async {
    final repository = ControlledFinancialRepository();

    await pumpDashboard(tester, repository);

    expect(
      find.byKey(const ValueKey('financial-empty-period-state')),
      findsOneWidget,
    );
    expect(
      find.text('Nenhum pedido encontrado para o período selecionado.'),
      findsOneWidget,
    );
  });

  testWidgets('exibe estado sem resultado quando a busca não encontra pedido',
      (tester) async {
    final repository = ControlledFinancialRepository(
      orders: [_order(id: 1, customer: 'Ana Souza', date: DateTime.now())],
    );

    await pumpDashboard(tester, repository);
    await tester.enterText(
      find.byKey(const ValueKey('financial-order-search')),
      'Cliente inexistente',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('financial-empty-search-state')),
      findsOneWidget,
    );
    expect(find.text('Nenhum pedido encontrado'), findsOneWidget);
  });

  testWidgets('exibe erro e permite tentar carregar novamente', (tester) async {
    final repository = ControlledFinancialRepository(
      error: StateError('falha ao carregar'),
    );

    await pumpDashboard(tester, repository);

    expect(
      find.byKey(const ValueKey('financial-error-state')),
      findsOneWidget,
    );
    expect(
      find.text('Não foi possível carregar os dados financeiros.'),
      findsOneWidget,
    );

    repository
      ..error = null
      ..orders = [_order(id: 2, customer: 'Bruno Lima', date: DateTime.now())];

    await tester.tap(find.byKey(const ValueKey('financial-error-retry')));
    await tester.pumpAndSettle();

    expect(repository.findAllCalls, 2);
    expect(
      find.byKey(const ValueKey('financial-error-state')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('financial-order-2')), findsOneWidget);
  });

  testWidgets('filtro Hoje exibe somente pedidos da data atual', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repository = ControlledFinancialRepository(
      orders: [
        _order(id: 10, customer: 'Hoje', date: today),
        _order(
          id: 20,
          customer: 'Ontem',
          date: today.subtract(const Duration(days: 1)),
        ),
      ],
    );

    await pumpDashboard(tester, repository);
    await tester.tap(
      find.byKey(const ValueKey('financial-period-today')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('financial-order-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('financial-order-20')), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('financial-summary-value-pedidos'),
            ),
          )
          .data,
      '1',
    );
  });

  testWidgets('filtro Ontem recalcula lista e resumo automaticamente',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repository = ControlledFinancialRepository(
      orders: [
        _order(id: 10, customer: 'Hoje', date: today, total: 100),
        _order(
          id: 20,
          customer: 'Ontem',
          date: today.subtract(const Duration(days: 1)),
          total: 250,
          status: 'Pago',
        ),
      ],
    );

    await pumpDashboard(tester, repository);
    await tester.tap(
      find.byKey(const ValueKey('financial-period-yesterday')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('financial-order-20')), findsOneWidget);
    expect(find.byKey(const ValueKey('financial-order-10')), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('financial-summary-value-total-em-vendas'),
            ),
          )
          .data,
      'R\$ 250,00',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('financial-status-pago-count')),
          )
          .data,
      '1',
    );
  });
}

Order _order({
  required int id,
  required String customer,
  required DateTime date,
  String status = 'Pendente',
  double total = 100,
}) {
  return Order(
    id: id,
    customerName: customer,
    paymentStatus: status,
    createdAt: date,
    items: [
      OrderItem(
        productId: 1,
        productName: 'Tênis',
        shoeSize: 40,
        quantity: 1,
        unitPrice: total,
        withBox: false,
      ),
    ],
  );
}
