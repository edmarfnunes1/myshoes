import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';
import 'package:myshoes/pages/financial/financial_order_view.dart';

void main() {
  group('filterAndSortFinancialOrders', () {
    final orders = [
      _order(
        id: 10,
        customer: 'Ana Souza',
        status: 'Pago',
        total: 100,
        date: DateTime(2026, 7, 10),
      ),
      _order(
        id: 20,
        customer: 'Bruno Lima',
        status: 'Pendente',
        total: 300,
        date: DateTime(2026, 7, 20),
      ),
      _order(
        id: 30,
        customer: 'Carlos Alves',
        status: 'Parcial',
        total: 200,
        date: DateTime(2026, 7, 15),
      ),
    ];

    test('pesquisa por nome do cliente sem diferenciar maiúsculas', () {
      final result = filterAndSortFinancialOrders(
        orders: orders,
        search: 'bruno',
      );

      expect(result.map((order) => order.id), [20]);
    });

    test('pesquisa pelo número do pedido com ou sem cerquilha', () {
      expect(
        filterAndSortFinancialOrders(orders: orders, search: '30').single.id,
        30,
      );
      expect(
        filterAndSortFinancialOrders(orders: orders, search: '#10').single.id,
        10,
      );
    });

    test('ordena dos pedidos mais recentes para os mais antigos', () {
      final result = filterAndSortFinancialOrders(
        orders: orders,
        sort: FinancialOrderSort.newest,
      );

      expect(result.map((order) => order.id), [20, 30, 10]);
    });

    test('ordena dos pedidos mais antigos para os mais recentes', () {
      final result = filterAndSortFinancialOrders(
        orders: orders,
        sort: FinancialOrderSort.oldest,
      );

      expect(result.map((order) => order.id), [10, 30, 20]);
    });

    test('ordena por maior e menor valor', () {
      final highest = filterAndSortFinancialOrders(
        orders: orders,
        sort: FinancialOrderSort.highestValue,
      );
      final lowest = filterAndSortFinancialOrders(
        orders: orders,
        sort: FinancialOrderSort.lowestValue,
      );

      expect(highest.map((order) => order.id), [20, 30, 10]);
      expect(lowest.map((order) => order.id), [10, 30, 20]);
    });

    test('coloca pedidos pendentes primeiro', () {
      final result = filterAndSortFinancialOrders(
        orders: orders,
        sort: FinancialOrderSort.pendingFirst,
      );

      expect(result.map((order) => order.id), [20, 30, 10]);
    });

    test('coloca pedidos parciais primeiro', () {
      final result = filterAndSortFinancialOrders(
        orders: orders,
        sort: FinancialOrderSort.partialFirst,
      );

      expect(result.map((order) => order.id), [30, 20, 10]);
    });

    test('aplica busca antes da ordenação', () {
      final result = filterAndSortFinancialOrders(
        orders: orders,
        search: 's',
        sort: FinancialOrderSort.highestValue,
      );

      expect(result.map((order) => order.id), [30, 10]);
    });
  });

  group('financialOrderItemsSummary', () {
    test('resume quantidade e nome dos itens', () {
      final order = Order(
        customerName: 'Cliente',
        items: [
          _item(name: 'Nike Air Max', quantity: 2, price: 100),
          _item(name: 'Adidas Samba', quantity: 1, price: 150),
        ],
      );

      expect(
        financialOrderItemsSummary(order),
        '2 Nike Air Max • 1 Adidas Samba',
      );
    });

    test('usa nome padrão quando o produto não possui descrição', () {
      final order = Order(
        customerName: 'Cliente',
        items: [_item(name: null, quantity: 1, price: 100)],
      );

      expect(financialOrderItemsSummary(order), '1 Tênis');
    });
  });
}

Order _order({
  required int id,
  required String customer,
  required String status,
  required double total,
  required DateTime date,
}) {
  return Order(
    id: id,
    customerName: customer,
    paymentStatus: status,
    createdAt: date,
    items: [_item(name: 'Tênis', quantity: 1, price: total)],
  );
}

OrderItem _item({
  required String? name,
  required int quantity,
  required double price,
}) {
  return OrderItem(
    productId: 1,
    productName: name,
    shoeSize: 40,
    quantity: quantity,
    unitPrice: price,
    withBox: false,
  );
}
