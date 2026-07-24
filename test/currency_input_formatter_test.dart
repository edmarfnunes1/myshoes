import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/widgets/currency_input_formatter.dart';

void main() {
  group('CurrencyInputFormatter', () {
    test('formata apenas os dígitos como moeda brasileira', () {
      final formatter = CurrencyInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12345'),
      );

      expect(result.text, 'R\$\u00a0123,45');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('retorna vazio quando não há dígitos', () {
      final formatter = CurrencyInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: 'R\$ 10,00'),
        const TextEditingValue(text: ''),
      );

      expect(result.text, isEmpty);
    });

    test('parse converte moeda formatada para double', () {
      expect(CurrencyInputFormatter.parse('R\$ 1.234,56'), 1234.56);
      expect(CurrencyInputFormatter.parse('2500'), 25);
    });

    test('parse retorna null sem dígitos', () {
      expect(CurrencyInputFormatter.parse(''), isNull);
      expect(CurrencyInputFormatter.parse('R\$'), isNull);
    });
  });
}
