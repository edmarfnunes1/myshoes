import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import '../widgets/app_page_header.dart';
import '../widgets/product_thumbnail.dart';
import '../pages/product_image_gallery_page.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _repository = ProductRepository();
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Product> _products = const [];
  bool _loading = true;

  final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadProducts();
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
    _debounce = Timer(const Duration(milliseconds: 300), _loadProducts);
  }

  Future<void> _loadProducts() async {
    if (mounted) setState(() => _loading = true);
    try {
      final products = await _repository.findAllWithImages(
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() => _products = products);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Product? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );

    if (saved != true || !mounted) return;
    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          product == null
              ? 'Tênis cadastrado com sucesso.'
              : 'Tênis atualizado com sucesso.',
        ),
      ),
    );
  }

  Future<void> _openGallery(Product product, {int initialIndex = 0}) async {
    final images = [...product.images]
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        return a.position.compareTo(b.position);
      });
    final paths = images
        .map((image) => image.imagePath.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProductImageGalleryPage(
          images: paths,
          initialIndex: initialIndex.clamp(0, paths.length - 1),
          productName: '${product.brand} — ${product.model}',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final productId = product.id;
    if (productId == null) return;

    final hasRelationships = await _repository.hasRelationships(productId);
    if (!mounted) return;

    if (hasRelationships) {
      final deactivate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Não é possível excluir'),
          content: const Text(
            'Este tênis já possui pedidos ou lotes vinculados e não pode ser excluído.\n\n'
            'Você pode desativá-lo para impedir que seja utilizado em novos pedidos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desativar tênis'),
            ),
          ],
        ),
      );

      if (deactivate == true) {
        await _setProductActive(product, false);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir tênis?'),
        content: const Text(
          'Deseja realmente excluir este tênis?\n'
          'Esta ação não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _repository.delete(productId);
    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tênis excluído.')),
    );
  }

  Future<void> _setProductActive(Product product, bool isActive) async {
    final productId = product.id;
    if (productId == null) return;

    await _repository.setActive(productId, isActive);
    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isActive ? 'Tênis reativado.' : 'Tênis desativado.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.black,
            width: 0.5,
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Novo tênis',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
       
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(
              title: 'Tênis',
              subtitle: 'Modelos cadastrados',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _SearchField(controller: _searchController),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.dark),
      );
    }

    if (_products.isEmpty) {
      return _EmptyProducts(
        isSearching: _searchController.text.trim().isNotEmpty,
        onAdd: () => _openForm(),
      );
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.neon,
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _ProductCard(
          product: _products[index],
          currency: _currency,
          onTap: () => _openForm(_products[index]),
          onEdit: () => _openForm(_products[index]),
          onDelete: () => _confirmDelete(_products[index]),
          onToggleActive: () => _setProductActive(
            _products[index],
            !_products[index].isActive,
          ),
          onOpenGallery: _products[index].images.isEmpty
              ? null
              : () => _openGallery(_products[index]),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: AppColors.neon,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Buscar por marca ou modelo',
        hintStyle: const TextStyle(color: Color(0xFF9EA7B6)),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFFD0D5DD),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded),
                color: const Color(0xFFD0D5DD),
              ),
        filled: true,
        fillColor: AppColors.dark,
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF263141)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.neon, width: 1.5),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onOpenGallery,
  });

  final Product product;
  final NumberFormat currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback? onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D131D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  key: const ValueKey('product-list-open-gallery'),
                  onTap: onOpenGallery,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProductThumbnail(product: product),
                      if (product.images.length > 1)
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.neon,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.dark, width: .7),
                            ),
                            child: Text(
                              '+${product.images.length - 1}',
                              style: const TextStyle(
                                color: AppColors.dark,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF667085),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        product.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.dark,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                      ),
                      if (!product.isActive) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF667085),
                              width: .8,
                            ),
                          ),
                          child: const Text(
                            'Inativo',
                            style: TextStyle(
                              color: Color(0xFF475467),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _InfoChip(
                            icon: Icons.straighten_rounded,
                            prefix: '',
                            value:
                                '${product.minimumSize} ao ${product.maximumSize}',
                          ),
                          _InfoChip(
                            icon: Icons.account_balance_wallet_outlined,
                            prefix: 'Custo ',
                            value: currency.format(product.costPrice),
                          ),
                          if (product.salePrice != null)
                            _InfoChip(
                              icon: Icons.sell_outlined,
                              prefix: 'Venda ',
                              value: currency.format(product.salePrice),
                              highlightValue: true,
                            ),
                        ],
                      ),
                      if (product.notes?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Text(
                          product.notes!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF667085),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.dark,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'toggle-active') onToggleActive();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 10),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle-active',
                      child: Row(
                        children: [
                          Icon(
                            product.isActive
                                ? Icons.block_rounded
                                : Icons.refresh_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            product.isActive
                                ? 'Desativar tênis'
                                : 'Reativar tênis',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Color(0xFFB42318),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Excluir',
                            style: TextStyle(color: Color(0xFFB42318)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.prefix,
    required this.value,
    this.highlightValue = false,
  });

  final IconData icon;
  final String prefix;
  final String value;
  final bool highlightValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.dark,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.dark),
          const SizedBox(width: 5),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.dark,
                    fontWeight: FontWeight.w600,
                  ),
              children: [
                TextSpan(text: prefix),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: highlightValue
                        ? const Color(0xFF8FB500)
                        : AppColors.dark,
                    fontWeight:
                        highlightValue ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.isSearching, required this.onAdd});

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
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.directions_run_rounded,
                size: 44,
                color: AppColors.neon,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching
                  ? 'Nenhum tênis encontrado'
                  : 'Nenhum tênis cadastrado',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Tente pesquisar usando outra marca ou modelo.'
                  : 'Cadastre os modelos recebidos da fábrica para começar a organizar seus pedidos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF667085),
                    height: 1.4,
                  ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Cadastrar primeiro tênis'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
