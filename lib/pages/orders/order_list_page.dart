import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import 'order_form_page.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({
    super.key,
    this.repository,
    this.formPageBuilder,
  });

  final OrderRepository? repository;
  final Widget Function(Order? order)? formPageBuilder;

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

enum _OrdersSection { ongoing, production }

class _OrderListPageState extends State<OrderListPage> {
  late final OrderRepository _repository;
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );
  Timer? _debounce;
  List<Order> _orders = const [];
  List<Order> _allOrders = const [];
  _OrdersSection _section = _OrdersSection.ongoing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OrderRepository();
    _load();
    _searchController.addListener(_search);
  }

  void _search() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final search = _searchController.text;
    final results = await Future.wait([
      _repository.findAll(search: search),
      if (search.trim().isNotEmpty) _repository.findAll() else Future.value(<Order>[]),
    ]);
    if (mounted) {
      setState(() {
        _orders = results.first;
        _allOrders = search.trim().isEmpty ? results.first : results.last;
        _loading = false;
      });
    }
  }

  Future<void> _pickOrderDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 10),
      helpText: 'Selecionar data do pedido',
      cancelText: 'Cancelar',
      confirmText: 'Pesquisar',
    );
    if (selectedDate == null) return;
    _searchController.text = _dateFormat.format(selectedDate);
  }

  Future<void> _open([Order? order]) async {
    if (order?.isInProductionBatch == true) {
      _showLockedOrderMessage(
        'Este pedido já foi enviado para a fábrica e não pode ser editado.',
      );
      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.formPageBuilder?.call(order) ??
            OrderFormPage(order: order),
      ),
    );
    if (saved == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              order == null
                  ? 'Pedido cadastrado com sucesso.'
                  : 'Pedido atualizado com sucesso.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(Order order) async {
    if (order.isInProductionBatch) {
      _showLockedOrderMessage(
        'Este pedido já foi enviado para a fábrica e não pode ser excluído.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir pedido?'),
        content: Text(
          'O pedido de ${order.customerName} será removido definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && order.id != null) {
      await _repository.delete(order.id!);
      await _load();
    }
  }


  void _showLockedOrderMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_search);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pedidos'),
            SizedBox(height: 2),
            Text(
              'Pedidos dos clientes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.black,
            width: 0.5,
          ),
        ),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Novo pedido'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Pesquisar por cliente, ID ou data',
                  hintText: 'Ex.: #15 ou 23/07/2026',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Selecionar data',
                        onPressed: _pickOrderDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Limpar pesquisa',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            _sectionSelector(),
            const SizedBox(height: 8),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _sectionSelector() {
    final ongoingCount = _allOrders.where((order) => !order.isInProductionBatch).length;
    final productionCount = _allOrders.where((order) => order.isInProductionBatch).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: _sectionButton(
                section: _OrdersSection.ongoing,
                label: 'Em andamento ($ongoingCount)',
                icon: Icons.pending_actions_outlined,
              ),
            ),
            Expanded(
              child: _sectionButton(
                section: _OrdersSection.production,
                label: 'Produção ($productionCount)',
                icon: Icons.factory_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionButton({
    required _OrdersSection section,
    required String label,
    required IconData icon,
  }) {
    final selected = _section == section;
    return Material(
      color: selected ? const Color(0xFF0D131D) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: ValueKey('orders-section-${section.name}'),
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() => _section = section),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? const Color(0xFFCCFF00) : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF202733),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Order> get _sectionOrders => _orders.where((order) {
        return _section == _OrdersSection.production
            ? order.isInProductionBatch
            : !order.isInProductionBatch;
      }).toList();

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final sectionOrders = _sectionOrders;
    if (sectionOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Nenhum pedido encontrado nesta seção.'
                    : _section == _OrdersSection.ongoing
                        ? 'Nenhum pedido em andamento.'
                        : 'Nenhum pedido enviado para produção.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_searchController.text.isEmpty &&
                  _section == _OrdersSection.ongoing)
                FilledButton.icon(
                  onPressed: () => _open(),
                  icon: const Icon(Icons.add),
                  label: const Text('Cadastrar pedido'),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: sectionOrders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, index) => _orderCard(sectionOrders[index]),
      ),
    );
  }

  Widget _orderCard(Order order) {
    final theme = Theme.of(context);
    final status = _normalizedStatus(order.paymentStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D131D),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _open(order),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(order, theme),
                const SizedBox(height: 20),
                _orderDetails(order, theme),
                const SizedBox(height: 18),
                _paymentFooter(order, theme, status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardHeader(Order order, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF0D131D),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Image.asset(
            'assets/images/tenis_neon4.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.sports_martial_arts_outlined,
              color: Color(0xFF245AA8),
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.id == null
                          ? 'Pedido'
                          : 'Pedido #${order.id!.toString().padLeft(4, '0')}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D131D),
                      ),
                    ),
                  ),
                  if (order.productionBatchId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Lote #${order.productionBatchId!.toString().padLeft(4, '0')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF303846),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  order.customerName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF0D131D),
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              order.createdAt == null
                  ? '--/--/----'
                  : _dateFormat.format(order.createdAt!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5C6675),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            if (order.isInProductionBatch)
              IconButton(
                tooltip: 'Pedido bloqueado: enviado para a fábrica',
                onPressed: () => _showLockedOrderMessage(
                  'Este pedido já foi enviado para a fábrica e não pode ser editado ou excluído.',
                ),
                icon: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF5C6675),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Opções do pedido',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_horiz,
                  color: Color(0xFF5C6675),
                ),
                onSelected: (value) =>
                    value == 'edit' ? _open(order) : _delete(order),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _orderDetails(Order order, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryBadge(
          Icons.inventory_2_outlined,
          '${order.totalQuantity} produto(s)',
        ),
        const SizedBox(height: 12),
        ...order.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              [
                item.productName ?? 'Produto',
                'Nº ${item.shoeSize}',
                if (item.color?.trim().isNotEmpty == true)
                  'Cor: ${item.color!.trim()}',
                'Qtd. ${item.quantity}',
                item.withBox ? 'C.Caixa' : 'S.Caixa',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF202733),
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentFooter(
    Order order,
    ThemeData theme,
    String status,
  ) {
    return Row(
      children: [
        Expanded(
          child: _footerPill(
            theme: theme,
            label: 'Pagamento',
            value: status,
            icon: _statusIcon(status),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _footerPill(
            theme: theme,
            label: 'Pagamento total',
            value: _currency.format(order.totalValue),
          ),
        ),
      ],
    );
  }

  Widget _footerPill({
    required ThemeData theme,
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFCCFF00),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF18733A),
            ),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF303820),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF0D131D),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF3E4652)),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF222832),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  String _normalizedStatus(String? value) {
    final status = value?.trim();
    return status == null || status.isEmpty ? 'Pendente' : status;
  }

  IconData _statusIcon(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('pago') || normalized.contains('concluído')) {
      return Icons.check_circle;
    }
    if (normalized.contains('parcial')) return Icons.timelapse;
    return Icons.schedule;
  }

}
