import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/product_repository.dart';
import '../models/product.dart';
import '../widgets/currency_input_formatter.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    this.product,
    this.repository,
  });

  final Product? product;
  final ProductRepository? repository;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProductRepository _repository;
  final _brandController = TextEditingController();
  final _brandFocusNode = FocusNode();
  final _modelController = TextEditingController();
  final _minimumSizeController = TextEditingController();
  final _maximumSizeController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _notesController = TextEditingController();

  static const _popularBrands = <String>[
  'Nike',
  'Adidas',
  'Puma',
  'New Balance',
  'Vans',
  'Lacoste',
  'Oakley',
  'Converse',
  'Asics',
  'Fila',
  'Reebok',
  'Under Armour',
  'Mizuno',
  'Olympikus',
  'Skechers',
  'Jordan',
  'Vert (Veja)',
  'Timberland',
  'DC Shoes',
  'Balenciaga',
];

  List<String> _availableBrands = _popularBrands;
  bool _saving = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProductRepository();
    final product = widget.product;
    _loadBrands();
    if (product == null) return;

    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    _brandController.text = product.brand;
    _modelController.text = product.model;
    _minimumSizeController.text = product.minimumSize.toString();
    _maximumSizeController.text = product.maximumSize.toString();
    _costPriceController.text = currency.format(product.costPrice);
    if (product.salePrice != null) {
      _salePriceController.text = currency.format(product.salePrice);
    }
    _notesController.text = product.notes ?? '';
  }

  @override
  void dispose() {
    _brandController.dispose();
    _brandFocusNode.dispose();
    _modelController.dispose();
    _minimumSizeController.dispose();
    _maximumSizeController.dispose();
    _costPriceController.dispose();
    _salePriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    List<String> savedBrands;
    try {
      savedBrands = await _repository.findBrands();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    final brands = <String>[];
    for (final brand in [..._popularBrands, ...savedBrands]) {
      final alreadyAdded = brands.any(
        (item) => item.toLowerCase() == brand.toLowerCase(),
      );
      if (!alreadyAdded) brands.add(brand);
    }

    setState(() => _availableBrands = brands);
  }

  void _selectBrand(String brand) {
    setState(() {
      _brandController.value = TextEditingValue(
        text: brand,
        selection: TextSelection.collapsed(offset: brand.length),
      );
    });
    _brandFocusNode.unfocus();
  }

  void _enterAnotherBrand() {
    setState(_brandController.clear);
    _brandFocusNode.requestFocus();
  }

  Iterable<String> _brandOptions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) return _availableBrands;
    return _availableBrands.where(
      (brand) => brand.toLowerCase().contains(query),
    );
  }

  Widget _buildBrandField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<String>(
          textEditingController: _brandController,
          focusNode: _brandFocusNode,
          optionsBuilder: _brandOptions,
          displayStringForOption: (brand) => brand,
          onSelected: _selectBrand,
          fieldViewBuilder: (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Marca *',
                prefixIcon: Icon(Icons.sell_outlined),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              validator: (value) => _requiredText(value, 'a marca'),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final items = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    minWidth: 280,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final brand = items[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.sell_outlined, size: 20),
                        title: Text(brand),
                        onTap: () => onSelected(brand),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'Marcas mais usadas',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF5A6575),
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._popularBrands.map((brand) {
              final selected =
                  _brandController.text.trim().toLowerCase() ==
                      brand.toLowerCase();
              return ChoiceChip(
                label: Text(brand),
                selected: selected,
                onSelected: (_) => _selectBrand(brand),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Outra'),
              onPressed: _enterAnotherBrand,
            ),
          ],
        ),
      ],
    );
  }

  String? _requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Informe $label.';
    return null;
  }

  String? _validateMinimumSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe a numeração mínima.';
    }
    final number = int.tryParse(value);
    if (number == null || number <= 0) return 'Informe uma numeração válida.';
    return null;
  }

  String? _validateMaximumSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe a numeração máxima.';
    }
    final maximum = int.tryParse(value);
    final minimum = int.tryParse(_minimumSizeController.text);
    if (maximum == null || maximum <= 0) {
      return 'Informe uma numeração válida.';
    }
    if (minimum != null && maximum < minimum) {
      return 'A numeração máxima deve ser igual ou maior que a mínima.';
    }
    return null;
  }

  String? _validateCost(String? value) {
    final amount = CurrencyInputFormatter.parse(value ?? '');
    if (amount == null) return 'Informe o valor de custo.';
    if (amount <= 0) return 'O valor de custo deve ser maior que zero.';
    return null;
  }

  String? _validateOptionalSalePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = CurrencyInputFormatter.parse(value);
    if (amount == null || amount <= 0) {
      return 'O valor de venda deve ser maior que zero.';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final product = Product(
        id: widget.product?.id,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        minimumSize: int.parse(_minimumSizeController.text),
        maximumSize: int.parse(_maximumSizeController.text),
        costPrice: CurrencyInputFormatter.parse(_costPriceController.text)!,
        salePrice: CurrencyInputFormatter.parse(_salePriceController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await _repository.save(product);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o produto.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar produto' : 'Novo produto'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                _editing
                    ? 'Atualize as informações do modelo.'
                    : 'Cadastre o modelo recebido da fábrica.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF5A6575),
                    ),
              ),
              const SizedBox(height: 24),
              _buildBrandField(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Modelo *',                  prefixIcon: Icon(Icons.directions_run_outlined),
                ),
                validator: (value) => _requiredText(value, 'o modelo'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minimumSizeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Numeração mínima *',
                      ),
                      validator: _validateMinimumSize,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maximumSizeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Numeração máxima *',
                      ),
                      validator: _validateMaximumSize,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor de custo *',                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: _validateCost,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salePriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor de venda',                  prefixIcon: Icon(Icons.price_check_outlined),
                ),
                validator: _validateOptionalSalePrice,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Observações',                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.notes_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Salvando...' : 'Salvar produto'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
