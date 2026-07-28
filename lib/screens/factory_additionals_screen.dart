import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/settings_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_page_header.dart';
import '../widgets/currency_input_formatter.dart';

class FactoryAdditionalsScreen extends StatefulWidget {
  const FactoryAdditionalsScreen({super.key, this.repository});

  final SettingsRepository? repository;

  @override
  State<FactoryAdditionalsScreen> createState() =>
      _FactoryAdditionalsScreenState();
}

class _FactoryAdditionalsScreenState extends State<FactoryAdditionalsScreen> {
  final _boxFormKey = GlobalKey<FormState>();
  final _boxFeeController = TextEditingController();
  late final SettingsRepository _repository;
  bool _loading = true;
  bool _savingBoxFee = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SettingsRepository();
    _loadBoxFee();
  }

  Future<void> _loadBoxFee() async {
    final value = await _repository.getBoxFee();
    if (!mounted) return;

    _boxFeeController.text = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(value);
    setState(() => _loading = false);
  }

  Future<void> _saveBoxFee() async {
    if (!_boxFormKey.currentState!.validate()) return;

    final value = CurrencyInputFormatter.parse(_boxFeeController.text)!;
    setState(() => _savingBoxFee = true);
    try {
      await _repository.saveBoxFee(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor da caixa salvo.')),
      );
    } finally {
      if (mounted) setState(() => _savingBoxFee = false);
    }
  }

  @override
  void dispose() {
    _boxFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const AppPageHeader(
              title: 'Adicionais da fábrica',
              subtitle: 'Valores de itens opcionais incluídos nos pedidos',
              horizontalPadding: 0,
            ),
            const SizedBox(height: 20),
            const _IntroductionCard(),
            const SizedBox(height: 14),
            _FactoryAdditionalCard(
              key: const ValueKey('box-additional-card'),
              icon: Icons.inventory_2_outlined,
              title: 'Caixa',
              description:
                  'Custo cobrado pela fábrica para cada par enviado com caixa.',
              child: Form(
                key: _boxFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: const ValueKey('box-fee-field'),
                      controller: _boxFeeController,
                      enabled: !_loading && !_savingBoxFee,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Valor por caixa',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      validator: (text) {
                        final value = CurrencyInputFormatter.parse(text ?? '');
                        if (value == null) return 'Informe o valor da caixa.';
                        if (value < 0) return 'O valor não pode ser negativo.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'O valor configurado será aplicado somente aos novos '
                      'itens adicionados aos pedidos. Itens já cadastrados '
                      'mantêm o valor registrado anteriormente.',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('save-box-fee'),
                        onPressed:
                            _loading || _savingBoxFee ? null : _saveBoxFee,
                        icon: _savingBoxFee
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Salvar valor'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune_rounded, color: AppColors.dark, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cadastre aqui os valores cobrados pela fábrica por itens '
              'opcionais. Novos adicionais poderão ser incluídos nesta tela '
              'sem alterar as configurações já existentes.',
              style: TextStyle(
                color: Color(0xFF4B5565),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoryAdditionalCard extends StatelessWidget {
  const _FactoryAdditionalCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.neon,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.dark, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.dark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
