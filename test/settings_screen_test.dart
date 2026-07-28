import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/settings_repository.dart';
import 'package:myshoes/screens/settings_screen.dart';

class FakeSettingsRepository extends SettingsRepository {
  FakeSettingsRepository({this.value = 5});

  double value;

  @override
  Future<double> getBoxFee() async => value;

  @override
  Future<void> saveBoxFee(double value) async {
    this.value = value;
  }
}

void main() {
  testWidgets('exibe e salva o valor da caixa', (tester) async {
    final repository = FakeSettingsRepository();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adicionais da fábrica'), findsOneWidget);
    expect(find.text('Sobre o app'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('factory-additionals-card')));
    await tester.pumpAndSettle();

    expect(find.text('Adicionais da fábrica'), findsOneWidget);
    expect(find.byKey(const ValueKey('box-additional-card')), findsOneWidget);
    expect(find.text('Caixa'), findsOneWidget);
    expect(find.text('Valor por caixa'), findsOneWidget);
    expect(
      find.textContaining(
        'O valor configurado será aplicado somente aos novos itens',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('box-fee-field')),
      'R\$ 7,50',
    );

    final saveButton = find.byKey(const ValueKey('save-box-fee'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.value, 7.5);
    expect(find.text('Valor da caixa salvo.'), findsOneWidget);
  });
}
