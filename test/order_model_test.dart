import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';

void main() {
  group('Order', () {
    test('calcula quantidade e valor total dos itens', () {
      final order = Order(
        customerName: 'Ana',
        items: const [
          OrderItem(
            productId: 1,
            shoeSize: 38,
            quantity: 2,
            withBox: false,
            unitPrice: 100,
          ),
          OrderItem(
            productId: 2,
            shoeSize: 40,
            quantity: 1,
            withBox: true,
            unitPrice: 250,
          ),
        ],
      );

      expect(order.totalQuantity, 3);
      expect(order.totalValue, 450);
    });

    test('toMap grava somente a data, sem horário', () {
      final order = Order(
        id: 7,
        customerName: 'Carlos',
        customerPhone: '44999990000',
        paymentStatus: 'Pago',
        notes: 'Teste',
        createdAt: DateTime(2026, 7, 23, 18, 45, 12),
        items: const [],
      );

      final map = order.toMap();

      expect(map['id'], 7);
      expect(map['created_at'], '2026-07-23');
    });

    test('fromMap converte os campos e mantém os itens recebidos', () {
      const items = [
        OrderItem(
          productId: 1,
          shoeSize: 39,
          quantity: 1,
          withBox: false,
          unitPrice: 199.90,
        ),
      ];

      final order = Order.fromMap(
        {
          'id': 12,
          'customer_name': 'Beatriz',
          'customer_phone': null,
          'payment_status': 'Parcial',
          'notes': null,
          'created_at': '2026-07-22',
          'production_batch_id': 8,
        },
        items: items,
      );

      expect(order.id, 12);
      expect(order.customerName, 'Beatriz');
      expect(order.paymentStatus, 'Parcial');
      expect(order.createdAt, DateTime(2026, 7, 22));
      expect(order.items, same(items));
      expect(order.productionBatchId, 8);
      expect(order.isInProductionBatch, isTrue);
    });


    test('identifica pedido vinculado a lote de produção', () {
      const order = Order(
        customerName: 'Ana',
        items: [],
        productionBatchId: 5,
      );

      expect(order.isInProductionBatch, isTrue);
    });

    test('identifica pedido ainda não enviado para a fábrica', () {
      const order = Order(
        customerName: 'Ana',
        items: [],
      );

      expect(order.isInProductionBatch, isFalse);
    });

    test('fromMap tolera data inválida', () {
      final order = Order.fromMap({
        'customer_name': 'Cliente',
        'created_at': 'data-inválida',
      });

      expect(order.createdAt, isNull);
    });
  });
}
