import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';

import '../../data/order_repository.dart';
import '../../data/product_repository.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../product_image_gallery_page.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/currency_input_formatter.dart';

class OrderFormPage extends StatefulWidget {
  const OrderFormPage({
    super.key,
    this.order,
    this.orderRepository,
    this.productRepository,
  });

  final Order? order;
  final OrderRepository? orderRepository;
  final ProductRepository? productRepository;

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final OrderRepository _orderRepository;
  late final ProductRepository _productRepository;
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  List<Product> _products = const [];
  List<OrderItem> _items = [];
  String? _paymentStatus;
  bool _loading = true;
  bool _saving = false;
  bool _openingContacts = false;

  static const _statuses = ['Pendente', 'Pago', 'Parcial'];

  bool get _paymentOnly => widget.order?.isInProductionBatch == true;

  @override
  void initState() {
    super.initState();
    _orderRepository = widget.orderRepository ?? OrderRepository();
    _productRepository = widget.productRepository ?? ProductRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    // Em produção, carregamos os tênis com suas miniaturas. Nos testes e em
    // outros consumidores que injetam um repositório, respeitamos o contrato
    // original de findAll(), evitando que um fake herde findAllWithImages() e
    // acesse o SQLite real por meio do ProductImageRepository.
    _products = widget.productRepository == null
        ? await _productRepository.findAllWithImages()
        : await _productRepository.findAll();

    var order = widget.order;
    if (order?.id != null) {
      order = await _orderRepository.findById(order!.id!) ?? order;
    }

    if (order != null) {
      _customerNameController.text = order.customerName;
      _customerPhoneController.text = order.customerPhone ?? '';
      _items = List<OrderItem>.from(order.items);
      _paymentStatus = order.paymentStatus;
      if (order.amountPaid > 0) {
        _amountPaidController.text = _currency.format(order.amountPaid);
      }
      _notesController.text = order.notes ?? '';
    }

    if (mounted) setState(() => _loading = false);
  }

  List<Product> get _activeProducts =>
      _products.where((product) => product.isActive).toList(growable: false);

  Product? _productById(int productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<void> _addItem() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProductPickerSheet(products: _activeProducts),
    );
    if (product == null || !mounted) return;

    final item = await showModalBottomSheet<OrderItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _OrderItemSheet(product: product),
    );
    if (item == null) return;

    setState(() => _mergeOrAdd(item));
  }

  Future<void> _editItem(int index) async {
    final current = _items[index];
    final product = _productById(current.productId);
    if (product == null) return;

    final edited = await showModalBottomSheet<OrderItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _OrderItemSheet(
        product: product,
        initialItem: current,
      ),
    );
    if (edited == null) return;

    setState(() {
      _items.removeAt(index);
      _mergeOrAdd(edited);
    });
  }

  void _mergeOrAdd(OrderItem item) {
    final existingIndex = _items.indexWhere(
      (current) =>
          current.productId == item.productId &&
          current.shoeSize == item.shoeSize &&
          (current.color ?? '').trim().toLowerCase() ==
              (item.color ?? '').trim().toLowerCase() &&
          current.withBox == item.withBox &&
          (current.unitPrice - item.unitPrice).abs() < 0.001,
    );

    if (existingIndex == -1) {
      _items.add(item);
      return;
    }

    final existing = _items[existingIndex];
    _items[existingIndex] = existing.copyWith(
      quantity: existing.quantity + item.quantity,
    );
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
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um tênis.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_paymentOnly) {
        await _orderRepository.updatePayment(
          orderId: widget.order!.id!,
          paymentStatus: _paymentStatus,
          amountPaid: _resolvedAmountPaid,
        );
      } else {
        await _orderRepository.save(
          Order(
            id: widget.order?.id,
            customerName: _customerNameController.text.trim(),
            customerPhone: _customerPhoneController.text.trim().isEmpty
                ? null
                : _customerPhoneController.text.trim(),
            items: _items,
            paymentStatus: _paymentStatus,
            amountPaid: _resolvedAmountPaid,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            createdAt: widget.order?.createdAt,
          ),
        );
      }
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

  double get _total => _items.fold(0, (sum, item) => sum + item.total);

  double get _resolvedAmountPaid {
    switch (_paymentStatus) {
      case 'Pago':
        return _total;
      case 'Parcial':
        return CurrencyInputFormatter.parse(_amountPaidController.text) ?? 0;
      default:
        return 0;
    }
  }

  void _changePaymentStatus(String? value) {
    setState(() {
      _paymentStatus = value;
      if (value == 'Pendente') {
        _amountPaidController.clear();
      } else if (value == 'Pago') {
        _amountPaidController.text = _currency.format(_total);
      }
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.order == null
              ? 'Novo pedido'
              : _paymentOnly
                  ? 'Atualizar pagamento'
                  : 'Editar pedido',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (_paymentOnly) ...[
                    Container(
                      key: const Key('production-payment-only-notice'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline_rounded),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este pedido já foi enviado para produção. Os itens não podem mais ser alterados, mas as informações de pagamento continuam disponíveis.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _sectionTitle(context, 'Cliente'),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customerNameController,
                          enabled: !_paymentOnly,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nome *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
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
                          onPressed: _paymentOnly || _openingContacts
                              ? null
                              : _pickContact,
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
                    enabled: !_paymentOnly,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle(context, 'Itens do pedido')),
                      Text(
                        '${_items.length} ${_items.length == 1 ? 'item' : 'itens'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 40),
                          SizedBox(height: 8),
                          Text('Nenhum tênis adicionado.'),
                        ],
                      ),
                    )
                  else
                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _items.length - 1 ? 0 : 12,
                        ),
                        child: _OrderItemCard(
                          item: item,
                          currency: _currency,
                          editable: !_paymentOnly,
                          onEdit: () => _editItem(index),
                          onDelete: () => setState(() => _items.removeAt(index)),
                        ),
                      );
                    }),
                  if (!_paymentOnly) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _activeProducts.isEmpty ? null : _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar tênis'),
                      ),
                    ),
                  ],
                  if (!_paymentOnly && _activeProducts.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Cadastre um tênis antes de lançar o pedido.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Total do pedido',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            _currency.format(_total),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return DropdownMenu<String>(
                        width: constraints.maxWidth,
                        initialSelection: _paymentStatus,
                        label: const Text('Situação do pagamento'),
                        leadingIcon: const Icon(
                          Icons.account_balance_wallet_outlined,
                        ),
                        trailingIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                        ),
                        selectedTrailingIcon: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                        ),
                        menuHeight: 180,
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 1.5,
                            ),
                          ),
                        ),
                        menuStyle: MenuStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            Theme.of(context).colorScheme.surface,
                          ),
                          elevation: const WidgetStatePropertyAll(4),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(vertical: 6),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        dropdownMenuEntries: _statuses
                            .map(
                              (status) => DropdownMenuEntry<String>(
                                value: status,
                                label: status,
                              ),
                            )
                            .toList(),
                        onSelected: _changePaymentStatus,
                      );
                    },
                  ),
                  if (_paymentStatus == 'Parcial') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('order-amount-paid-field'),
                      controller: _amountPaidController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Valor pago *',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        if (_paymentStatus != 'Parcial') return null;
                        final amount = CurrencyInputFormatter.parse(value ?? '');
                        if (amount == null || amount <= 0) {
                          return 'Informe um valor pago maior que R\$ 0,00.';
                        }
                        if (amount >= _total) {
                          return 'O valor pago deve ser menor que o total do pedido.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    enabled: !_paymentOnly,
                    maxLines: 2,
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
                    label: Text(
                      _saving
                          ? 'Salvando...'
                          : _paymentOnly
                              ? 'Atualizar pagamento'
                              : 'Salvar pedido',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _OrderItemCard extends StatelessWidget {
  const _OrderItemCard({
    required this.item,
    required this.currency,
    required this.editable,
    required this.onEdit,
    required this.onDelete,
  });

  final OrderItem item;
  final NumberFormat currency;
  final bool editable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  child: Icon(Icons.directions_run_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'Tênis',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(label: 'Nº ${item.shoeSize}'),
                          if (item.color?.trim().isNotEmpty == true)
                            _InfoChip(label: 'Cor: ${item.color!.trim()}'),
                          _InfoChip(label: 'Qtd. ${item.quantity}'),
                          _InfoChip(
                            label: item.withBox ? 'Com caixa' : 'Sem caixa',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (editable)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar item')),
                      PopupMenuItem(value: 'delete', child: Text('Remover item')),
                    ],
                  )
                else
                  const Icon(Icons.lock_outline_rounded),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${currency.format(item.unitPrice)} cada',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  currency.format(item.total),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _OrderItemSheet extends StatefulWidget {
  const _OrderItemSheet({required this.product, this.initialItem});

  final Product product;
  final OrderItem? initialItem;

  @override
  State<_OrderItemSheet> createState() => _OrderItemSheetState();
}

class _OrderItemSheetState extends State<_OrderItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _colorController = TextEditingController();
  int? _shoeSize;
  int _quantity = 1;
  bool _withBox = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _shoeSize = item?.shoeSize;
    _colorController.text = item?.color ?? '';
    _quantity = item?.quantity ?? 1;
    _withBox = item?.withBox ?? false;
    final value = item?.unitPrice ?? widget.product.salePrice;
    if (value != null) {
      _valueController.text = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
        decimalDigits: 2,
      ).format(value);
    }
  }

  List<int> get _sizes => [
        for (
          var size = widget.product.minimumSize;
          size <= widget.product.maximumSize;
          size++
        )
          size,
      ];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      OrderItem(
        productId: widget.product.id!,
        shoeSize: _shoeSize!,
        color: _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        quantity: _quantity,
        withBox: _withBox,
        unitPrice: CurrencyInputFormatter.parse(_valueController.text)!,
        productName: '${widget.product.brand} ${widget.product.model}',
      ),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomSafeArea),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initialItem == null
                          ? 'Configurar tênis'
                          : 'Editar item',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.product.brand} ${widget.product.model}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Numerações ${widget.product.minimumSize} a ${widget.product.maximumSize}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _ProductPhotoPreview(product: widget.product),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 128,
                    child: DropdownButtonFormField<int>(
                      initialValue: _shoeSize,
                      alignment: Alignment.center,
                      decoration: const InputDecoration(
                        labelText: 'Numeração *',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: _sizes
                          .map(
                            (size) => DropdownMenuItem(
                              value: size,
                              alignment: Alignment.center,
                              child: Text(size.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _shoeSize = value),
                      validator: (value) => value == null
                          ? 'Selecione a numeração.'
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 156,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            'Quantidade *',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                icon: const Icon(Icons.remove),
                              ),
                              Text(
                                '$_quantity',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              IconButton(
                                key: const ValueKey('order-item-quantity-increase'),
                                onPressed: () => setState(() => _quantity++),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _withBox = !_withBox),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _withBox,
                            onChanged: (value) =>
                                setState(() => _withBox = value ?? false),
                          ),
                          const Text('Com caixa'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Cor',
                  prefixIcon: Icon(Icons.palette_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor unitário *',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final amount = CurrencyInputFormatter.parse(value ?? '');
                  return amount == null || amount <= 0
                      ? 'Informe um valor válido.'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              Row(
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
                      onPressed: _submit,
                      child: Text(
                        widget.initialItem == null ? 'Adicionar' : 'Salvar',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ProductPhotoPreview extends StatelessWidget {
  const _ProductPhotoPreview({required this.product});

  final Product product;

  List<String> get _imagePaths {
    final images = [...product.images]
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        return a.position.compareTo(b.position);
      });
    return images
        .map((image) => image.imagePath.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _openGallery(BuildContext context) async {
    final paths = _imagePaths;
    if (paths.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProductImageGalleryPage(
          images: paths,
          productName: '${product.brand} — ${product.model}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = product.images.length;
    final hasImages = imageCount > 0 && _imagePaths.isNotEmpty;

    return Container(
      key: const ValueKey('order-product-photo-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ProductThumbnail(
                key: const ValueKey('order-product-primary-photo'),
                product: product,
                size: 92,
                borderRadius: 14,
              ),
              if (imageCount > 1)
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    key: const ValueKey('order-product-more-photos-badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onPrimary,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '+${imageCount - 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasImages ? 'Foto principal' : 'Imagem não cadastrada',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  imageCount == 0
                      ? 'Ícone padrão do tênis'
                      : imageCount == 1
                          ? '🖼 1 foto disponível'
                          : '🖼 $imageCount fotos disponíveis',
                  key: const ValueKey('order-product-photo-count'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (hasImages) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('order-product-open-gallery'),
                    onPressed: () => _openGallery(context),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Ver galeria'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.products});

  final List<Product> products;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  Product? _selectedProduct;
  String _search = '';

  List<Product> get _filteredProducts {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return widget.products;
    return widget.products.where((product) {
      return '${product.brand} ${product.model}'
          .toLowerCase()
          .contains(query);
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
                      'Selecionar tênis',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
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
                decoration: InputDecoration(
                  labelText: 'Pesquisar tênis',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
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
                  ? const Center(child: Text('Nenhum tênis encontrado.'))
                  : RadioGroup<Product>(
                      groupValue: _selectedProduct,
                      onChanged: (value) =>
                          setState(() => _selectedProduct = value),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filteredProducts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return RadioListTile<Product>(
                            value: product,
                            selected: product.id == _selectedProduct?.id,
                            secondary: ProductThumbnail(
                              product: product,
                              size: 48,
                              borderRadius: 12,
                            ),
                            title: Text('${product.brand} ${product.model}'),
                            subtitle: Text(
                              'Numerações ${product.minimumSize} a ${product.maximumSize}'
                              '${product.salePrice == null ? '' : ' • ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2).format(product.salePrice)}'}'
                              '${product.images.isEmpty ? '' : ' • ${product.images.length} ${product.images.length == 1 ? 'foto' : 'fotos'}'}',
                            ),
                          );
                        },
                      ),
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
                          : () => Navigator.pop(context, _selectedProduct),
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
