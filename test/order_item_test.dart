import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/models/order_item.dart';

void main() {
  group('OrderItem', () {
    test('calcula o total pela quantidade e valor unitário', () {
      const item = OrderItem(
        productId: 1,
        shoeSize: 38,
        quantity: 3,
        withBox: false,
        unitPrice: 129.90,
      );

      expect(item.total, closeTo(389.70, 0.001));
    });

    test('converte para mapa e retorna com cor e caixa', () {
      const item = OrderItem(
        id: 5,
        orderId: 2,
        productId: 9,
        shoeSize: 40,
        color: 'Azul marinho',
        quantity: 2,
        withBox: true,
        unitPrice: 220,
        costPriceUnit: 140,
        boxFeeUnit: 7.5,
        productName: 'Adidas A3',
      );

      final result = OrderItem.fromMap({
        ...item.toMap(),
        'product_name': 'Adidas A3',
      });

      expect(result.id, 5);
      expect(result.orderId, 2);
      expect(result.color, 'Azul marinho');
      expect(result.withBox, isTrue);
      expect(result.productName, 'Adidas A3');
      expect(result.costPriceUnit, 140);
      expect(result.shoeCostTotal, 280);
      expect(result.boxFeeUnit, 7.5);
      expect(result.boxFeeTotal, 15);
      expect(result.totalCost, 295);
      expect(result.profit, 145);
    });

    test('mapa antigo assume custos históricos iguais a zero', () {
      final item = OrderItem.fromMap({
        'id': 1,
        'order_id': 2,
        'product_id': 3,
        'shoe_size': 39,
        'quantity': 1,
        'with_box': 1,
        'unit_price': 200.0,
      });

      expect(item.costPriceUnit, 0);
      expect(item.boxFeeUnit, 0);
      expect(item.totalCost, 0);
      expect(item.profit, 200);
    });

    test('copyWith altera a cor e a quantidade', () {
      const item = OrderItem(
        productId: 1,
        shoeSize: 38,
        color: 'Preto',
        quantity: 1,
        withBox: false,
        unitPrice: 100,
      );

      final changed = item.copyWith(color: 'Branco', quantity: 3);

      expect(changed.color, 'Branco');
      expect(changed.quantity, 3);
      expect(changed.shoeSize, 38);
    });

    test('copyWith permite limpar a cor', () {
      const item = OrderItem(
        productId: 1,
        shoeSize: 38,
        color: 'Preto',
        quantity: 1,
        withBox: false,
        unitPrice: 100,
      );

      expect(item.copyWith(clearColor: true).color, isNull);
    });
  });
}
