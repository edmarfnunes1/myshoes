import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';
import 'package:myshoes/pages/financial/financial_summary.dart';

void main() {
  group('FinancialSummary', () {
    test('calcula valores e quantidades por situação de pagamento', () {
      final orders = [
        _order(status: 'Pago', total: 100),
        _order(status: 'Parcial', total: 200, amountPaid: 80),
        _order(status: 'Pendente', total: 300),
      ];

      final summary = FinancialSummary.fromOrders(orders);

      expect(summary.received, 180);
      expect(summary.pending, 420);
      expect(summary.totalSales, 600);
      expect(summary.orders, 3);
      expect(summary.paidOrders, 1);
      expect(summary.partialOrders, 1);
      expect(summary.pendingOrders, 1);
    });

    test('considera situação vazia ou desconhecida como pendente', () {
      final summary = FinancialSummary.fromOrders([
        _order(status: null, total: 100),
        _order(status: '', total: 150),
        _order(status: 'Outro', total: 50),
      ]);

      expect(summary.received, 0);
      expect(summary.pending, 300);
      expect(summary.pendingOrders, 3);
    });

    test('limita valor parcial entre zero e o total do pedido', () {
      final summary = FinancialSummary.fromOrders([
        _order(status: 'Parcial', total: 100, amountPaid: -20),
        _order(status: 'Parcial', total: 200, amountPaid: 250),
      ]);

      expect(summary.received, 200);
      expect(summary.pending, 100);
      expect(summary.partialOrders, 2);
    });
  });
}

Order _order({
  required String? status,
  required double total,
  double amountPaid = 0,
}) {
  return Order(
    customerName: 'Cliente',
    paymentStatus: status,
    amountPaid: amountPaid,
    createdAt: DateTime(2026, 7, 1),
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
