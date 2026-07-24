import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/models/product.dart';

void main() {
  test('converte produto para mapa e retorna corretamente', () {
    const product = Product(
      id: 1,
      brand: 'Nike',
      model: 'Dunk Glitter',
      minimumSize: 34,
      maximumSize: 36,
      costPrice: 80,
      salePrice: 120,
      notes: 'Teste',
    );

    final result = Product.fromMap(product.toMap());

    expect(result.id, 1);
    expect(result.brand, 'Nike');
    expect(result.model, 'Dunk Glitter');
    expect(result.minimumSize, 34);
    expect(result.maximumSize, 36);
    expect(result.costPrice, 80);
    expect(result.salePrice, 120);
    expect(result.notes, 'Teste');
  });


  test('copyWith altera campos e permite limpar valores opcionais', () {
    const product = Product(
      id: 1,
      brand: 'Nike',
      model: 'Air Max',
      minimumSize: 34,
      maximumSize: 44,
      costPrice: 100,
      salePrice: 200,
      notes: 'Original',
    );

    final changed = product.copyWith(
      model: 'Air Max Plus',
      clearSalePrice: true,
      clearNotes: true,
    );

    expect(changed.id, 1);
    expect(changed.brand, 'Nike');
    expect(changed.model, 'Air Max Plus');
    expect(changed.salePrice, isNull);
    expect(changed.notes, isNull);
  });
}
