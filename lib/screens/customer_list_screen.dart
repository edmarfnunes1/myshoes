import 'dart:async';

import 'package:flutter/material.dart';

import '../data/customer_repository.dart';
import '../models/customer.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _repository = CustomerRepository();
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Customer> _customers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadCustomers);
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    try {
      final customers = await _repository.findAll(
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() => _customers = customers);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Customer? customer]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customer: customer),
      ),
    );

    if (saved != true || !mounted) return;
    await _loadCustomers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          customer == null
              ? 'Cliente cadastrado com sucesso.'
              : 'Cliente atualizado com sucesso.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text(
          'O cliente ${customer.name} será removido definitivamente.',
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

    if (confirmed != true || customer.id == null) return;
    await _repository.delete(customer.id!);
    await _loadCustomers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cliente excluído.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clientes'),
            SizedBox(height: 2),
            Text(
              'Clientes cadastrados',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Novo cliente'),
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
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_customers.isEmpty) {
      return _EmptyCustomers(
        isSearching: _searchController.text.trim().isNotEmpty,
        onAdd: () => _openForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCustomers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: _customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final customer = _customers[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openForm(customer),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        customer.name.trim().isEmpty
                            ? '?'
                            : customer.name.trim()[0].toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (customer.phone != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 17),
                                const SizedBox(width: 6),
                                Expanded(child: Text(customer.phone!)),
                              ],
                            ),
                          ],
                          if (customer.notes != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              customer.notes!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: const Color(0xFF667085)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _openForm(customer);
                        if (value == 'delete') _confirmDelete(customer);
                      },
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
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.isSearching, required this.onAdd});

  final bool isSearching;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.people_outline,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              isSearching
                  ? 'Nenhum cliente encontrado'
                  : 'Nenhum cliente cadastrado',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Tente pesquisar usando outro nome ou telefone.'
                  : 'Cadastre seus clientes para vinculá-los aos próximos pedidos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF667085),
                  ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar cliente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
