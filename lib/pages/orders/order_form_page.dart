import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';

import '../../data/order_repository.dart';
import '../../data/product_repository.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../widgets/currency_input_formatter.dart';

class OrderFormPage extends StatefulWidget {
  const OrderFormPage({super.key, this.order});

  final Order? order;

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _orderRepository = OrderRepository();
  final _productRepository = ProductRepository();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();

  List<Product> _products = const [];
  Product? _product;
  int? _shoeSize;
  int _quantity = 1;
  bool _withBox = false;
  String? _paymentStatus;
  bool _loading = true;
  bool _saving = false;
  bool _openingContacts = false;

  static const _statuses = ['Pendente', 'Pago', 'Parcial'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _products = await _productRepository.findAll();

    final order = widget.order;
    if (order != null) {
      _customerNameController.text = order.customerName;
      _customerPhoneController.text = order.customerPhone ?? '';
      _product = _products.where((e) => e.id == order.productId).firstOrNull;
      _shoeSize = order.shoeSize;
      _quantity = order.quantity;
      _withBox = order.withBox;
      _paymentStatus = order.paymentStatus;
      _notesController.text = order.notes ?? '';
      _valueController.text = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
        decimalDigits: 2,
      ).format(order.saleValue);
    }

    if (mounted) setState(() => _loading = false);
  }

  List<int> get _sizes {
    final product = _product;
    if (product == null) return const [];
    return [
      for (var size = product.minimumSize;
          size <= product.maximumSize;
          size++)
        size,
    ];
  }

  void _selectProduct(Product? product) {
    setState(() {
      _product = product;
      _shoeSize = null;
      if (product?.salePrice != null) {
        _valueController.text = NumberFormat.currency(
          locale: 'pt_BR',
          symbol: 'R\$',
          decimalDigits: 2,
        ).format(product!.salePrice);
      }
    });
  }

  Future<void> _showProductPicker() async {
    final selectedProduct = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProductPickerSheet(
        products: _products,
        initialProduct: _product,
      ),
    );

    if (selectedProduct != null) {
      _selectProduct(selectedProduct);
    }
  }

  Future<void> _pickContact() async {
    if (_openingContacts) return;
    setState(() => _openingContacts = true);

    try {
      var permission = await FlutterContacts.permissions.check(
        PermissionType.read,
      );
      if (permission != PermissionStatus.granted) {
        permission = await FlutterContacts.permissions.request(
          PermissionType.read,
        );
      }

      if (permission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permita o acesso aos contatos para selecionar um cliente.',
              ),
            ),
          );
        }
        return;
      }

      final contact = await FlutterContacts.native.showPicker(
        properties: const {
          ContactProperty.name,
          ContactProperty.phone,
        },
      );
      if (contact == null) return;

      final phone = contact.phones.isEmpty ? '' : contact.phones.first.number;
      _customerNameController.text = contact.displayName?.trim() ?? '';
      _customerPhoneController.text = phone.trim();

      if (mounted) setState(() {});
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a agenda do celular.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingContacts = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _orderRepository.save(
        Order(
          id: widget.order?.id,
          customerName: _customerNameController.text.trim(),
          customerPhone: _customerPhoneController.text.trim().isEmpty
              ? null
              : _customerPhoneController.text.trim(),
          productId: _product!.id!,
          shoeSize: _shoeSize!,
          quantity: _quantity,
          withBox: _withBox,
          saleValue: CurrencyInputFormatter.parse(_valueController.text)!,
          paymentStatus: _paymentStatus,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          createdAt: widget.order?.createdAt,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o pedido.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Novo pedido' : 'Editar pedido'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    'Cliente',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customerNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nome *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Informe o nome do cliente.'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: IconButton.filledTonal(
                          tooltip: 'Selecionar da agenda',
                          onPressed: _openingContacts ? null : _pickContact,
                          icon: _openingContacts
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.contacts_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Produtos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FormField<Product>(
                    initialValue: _product,
                    validator: (_) =>
                        _product == null ? 'Adicione um produto.' : null,
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_product == null)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showProductPicker,
                                icon: const Icon(Icons.add),
                                label: const Text('Adicionar produto'),
                              ),
                            )
                          else
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const CircleAvatar(
                                          child: Icon(
                                            Icons.directions_run_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${_product!.brand} ${_product!.model}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Numerações ${_product!.minimumSize} a ${_product!.maximumSize}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                              if (_product!.salePrice != null)
                                                Text(
                                                  NumberFormat.currency(
                                                    locale: 'pt_BR',
                                                    symbol: 'R\$',
                                                    decimalDigits: 2,
                                                  ).format(
                                                    _product!.salePrice,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remover produto',
                                          onPressed: () {
                                            _selectProduct(null);
                                            field.didChange(null);
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: _showProductPicker,
                                        icon: const Icon(Icons.swap_horiz),
                                        label: const Text('Trocar produto'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (field.hasError) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _shoeSize,
                    decoration: const InputDecoration(
                      labelText: 'Numeração *',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    items: _sizes
                        .map(
                          (size) => DropdownMenuItem(
                            value: size,
                            child: Text(size.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: _product == null
                        ? null
                        : (value) => setState(() => _shoeSize = value),
                    validator: (value) =>
                        value == null ? 'Selecione a numeração.' : null,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Quantidade *',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: Text(
                            '$_quantity',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _withBox,
                    title: const Text('Com caixa'),
                    subtitle: const Text(
                      'Desmarcado será considerado sem caixa.',
                    ),
                    onChanged: (value) =>
                        setState(() => _withBox = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Valor de venda *',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (value) {
                      final amount =
                          CurrencyInputFormatter.parse(value ?? '');
                      return amount == null || amount <= 0
                          ? 'Informe um valor de venda válido.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Situação do pagamento',
                      prefixIcon:
                          Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: _statuses
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _paymentStatus = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Salvando...' : 'Salvar pedido'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({
    required this.products,
    this.initialProduct,
  });

  final List<Product> products;
  final Product? initialProduct;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  Product? _selectedProduct;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  List<Product> get _filteredProducts {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return widget.products;

    return widget.products.where((product) {
      final name = '${product.brand} ${product.model}'.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Adicionar produto',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Pesquisar produto',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar pesquisa',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(
                      child: Text('Nenhum produto encontrado.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final selected = product.id == _selectedProduct?.id;

                        return RadioListTile<Product>(
                          value: product,
                          groupValue: _selectedProduct,
                          onChanged: (value) =>
                              setState(() => _selectedProduct = value),
                          selected: selected,
                          title: Text('${product.brand} ${product.model}'),
                          subtitle: Text(
                            'Numerações ${product.minimumSize} a ${product.maximumSize}'
                            '${product.salePrice == null ? '' : ' • ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2).format(product.salePrice)}'}',
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selectedProduct == null
                          ? null
                          : () => Navigator.pop(
                                context,
                                _selectedProduct,
                              ),
                      child: const Text('Selecionar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
