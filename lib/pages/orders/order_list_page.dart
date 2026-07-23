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

class _OrderListPageState extends State<OrderListPage> {
  late final OrderRepository _repository;
  final _searchController = TextEditingController();
  final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );
  Timer? _debounce;
  List<Order> _orders = const [];
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
    final orders = await _repository.findAll(search: _searchController.text);
    if (mounted) {
      setState(() {
        _orders = orders;
        _loading = false;
      });
    }
  }

  Future<void> _open([Order? order]) async {
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
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty
                    ? 'Nenhum pedido cadastrado.'
                    : 'Nenhum pedido encontrado.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_searchController.text.isEmpty)
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
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final order = _orders[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _open(order),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (order.customerPhone?.isNotEmpty == true) ...[
                            const SizedBox(height: 3),
                            Text(
                              order.customerPhone!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 8),
                          ...order.items.take(3).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    '${item.productName ?? 'Produto'} • Nº ${item.shoeSize} • Qtd. ${item.quantity}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          if (order.items.length > 3)
                            Text(
                              '+ ${order.items.length - 3} item(ns)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(
                                Icons.inventory_2_outlined,
                                '${order.totalQuantity} produto(s)',
                              ),
                              _chip(
                                Icons.payments_outlined,
                                _currency.format(order.totalValue),
                              ),
                              if (order.paymentStatus != null)
                                _chip(
                                  Icons.account_balance_wallet_outlined,
                                  order.paymentStatus!,
                                ),
                            ],
                          ),
                          if (order.notes?.isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Text(
                              order.notes!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) =>
                          value == 'edit' ? _open(order) : _delete(order),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 5),
            Text(text),
          ],
        ),
      );
}
