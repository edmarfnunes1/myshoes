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
