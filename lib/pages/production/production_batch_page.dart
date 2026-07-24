import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/production_batch_repository.dart';
import '../../models/order.dart';
import '../../models/production_batch.dart';
import '../../services/production_batch_pdf_service.dart';
import '../../services/production_batch_text_service.dart';
import '../../theme/app_colors.dart';

class ProductionBatchPage extends StatefulWidget {
  const ProductionBatchPage({
    super.key,
    this.repository,
    this.refreshToken = 0,
  });

  final ProductionBatchRepository? repository;
  final int refreshToken;

  @override
  State<ProductionBatchPage> createState() => _ProductionBatchPageState();
}

class _ProductionBatchPageState extends State<ProductionBatchPage> {
  late final ProductionBatchRepository _repository;
  final _selectedOrderIds = <int>{};
  final _date = DateFormat('dd/MM/yyyy');
  final _pdfService = ProductionBatchPdfService();
  final _textService = const ProductionBatchTextService();
  List<Order> _orders = const [];
  List<ProductionBatch> _batches = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProductionBatchRepository();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductionBatchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final results = await Future.wait([
      _repository.findAvailableOrders(),
      _repository.findBatches(),
    ]);
    if (!mounted) return;
    setState(() {
      _orders = results[0] as List<Order>;
      _batches = results[1] as List<ProductionBatch>;
      _selectedOrderIds.removeWhere(
        (id) => !_orders.any((order) => order.id == id),
      );
      _loading = false;
    });
  }

  Future<void> _createBatch() async {
    final selected = _selectedOrderIds.toList()..sort();
    if (selected.isEmpty) return;
    final totalPairs = _orders
        .where((order) => selected.contains(order.id))
        .fold<int>(0, (sum, order) => sum + order.totalQuantity);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Criar lote para a fábrica?'),
        content: Text(
          '${selected.length} pedido(s) e $totalPairs par(es) serão incluídos. '
          'Depois disso, esses pedidos não aparecerão na seleção de novos lotes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar lote'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = await _repository.createBatch(selected);
    _selectedOrderIds.clear();
    await _load();
    if (!mounted) return;
    final batch = _batches.firstWhere((item) => item.id == id);
    final rows = await _repository.consolidateBatch(id);
    if (!mounted) return;
    await _showCreatedBatchActions(batch, rows);
  }

  Future<void> _showCreatedBatchActions(
    ProductionBatch batch,
    List<ProductionConsolidationRow> rows,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lote criado com sucesso'),
        content: Text(
          'O lote #${batch.formattedId} possui ${batch.orderCount} pedido(s) '
          'e ${batch.totalPairs} par(es).',
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _runTextAction(
                () => _textService.share(batch: batch, rows: rows),
              );
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Compartilhar texto'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _runPdfAction(
                () => _pdfService.preview(batch: batch, rows: rows),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Visualizar PDF'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _runPdfAction(
                () => _pdfService.share(batch: batch, rows: rows),
              );
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartilhar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openBatch(batch);
            },
            child: const Text('Abrir lote'),
          ),
        ],
      ),
    );
  }

  Future<void> _runPdfAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
    }
  }

  Future<void> _runTextAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível compartilhar o texto.')),
      );
    }
  }

  Future<void> _openBatch(ProductionBatch batch) async {
    final rows = await _repository.consolidateBatch(batch.id);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionBatchDetailPage(
          batch: batch,
          rows: rows,
          pdfService: _pdfService,
        ),
      ),
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
            Text('Fábrica'),
            SizedBox(height: 2),
            Text(
              'Consolidação de pedidos',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  _selectionHeader(),
                  const SizedBox(height: 12),
                  if (_orders.isEmpty)
                    _emptyOrders()
                  else
                    ..._orders.map(_orderTile),
                  const SizedBox(height: 28),
                  Text(
                    'Histórico de lotes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_batches.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Nenhum lote criado até o momento.'),
                      ),
                    )
                  else
                    ..._batches.map(_batchTile),
                ],
              ),
            ),
      bottomNavigationBar: _selectedOrderIds.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: FilledButton.icon(
                  onPressed: _createBatch,
                  icon: const Icon(Icons.factory_outlined),
                  label: Text(
                    'Criar lote (${_selectedOrderIds.length} pedido(s))',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _selectionHeader() {
    final allSelected = _orders.isNotEmpty &&
        _orders.every((order) => _selectedOrderIds.contains(order.id));
    return Row(
      children: [
        Expanded(
          child: Text(
            'Selecione os pedidos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (_orders.isNotEmpty)
          TextButton(
            onPressed: () => setState(() {
              if (allSelected) {
                _selectedOrderIds.clear();
              } else {
                _selectedOrderIds.addAll(_orders.map((order) => order.id!));
              }
            }),
            child: Text(allSelected ? 'Limpar' : 'Selecionar todos'),
          ),
      ],
    );
  }

  Widget _emptyOrders() => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.task_alt, size: 48),
              SizedBox(height: 12),
              Text(
                'Todos os pedidos já foram incluídos em lotes.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _orderTile(Order order) {
    final id = order.id!;
    final selected = _selectedOrderIds.contains(id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: selected,
        activeColor: AppColors.dark,
        checkColor: AppColors.neon,
        onChanged: (value) => setState(() {
          value == true
              ? _selectedOrderIds.add(id)
              : _selectedOrderIds.remove(id);
        }),
        title: Text(
          'Pedido #${id.toString().padLeft(4, '0')} · ${order.customerName}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${order.totalQuantity} par(es) · ${order.items.length} item(ns) · '
          '${order.createdAt == null ? '--/--/----' : _date.format(order.createdAt!)}',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Future<void> _exportBatchFromHistory(ProductionBatch batch) async {
    final rows = await _repository.consolidateBatch(batch.id);
    if (!mounted) return;
    await _runPdfAction(() => _pdfService.share(batch: batch, rows: rows));
  }

  Future<void> _shareBatchTextFromHistory(ProductionBatch batch) async {
    final rows = await _repository.consolidateBatch(batch.id);
    if (!mounted) return;
    await _runTextAction(() => _textService.share(batch: batch, rows: rows));
  }

  Widget _batchTile(ProductionBatch batch) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: () => _openBatch(batch),
          leading: CircleAvatar(
            backgroundColor: AppColors.dark,
            foregroundColor: AppColors.neon,
            child: const Icon(Icons.factory_outlined),
          ),
          title: Text(
            'Lote #${batch.id.toString().padLeft(4, '0')}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${_date.format(batch.createdAt)} · ${batch.orderCount} pedido(s) · '
            '${batch.totalPairs} par(es)',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Compartilhar texto',
                onPressed: () => _shareBatchTextFromHistory(batch),
                icon: const Icon(Icons.chat_outlined),
              ),
              IconButton(
                tooltip: 'Exportar PDF',
                onPressed: () => _exportBatchFromHistory(batch),
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
            ],
          ),
        ),
      );
}

class ProductionBatchDetailPage extends StatefulWidget {
  const ProductionBatchDetailPage({
    super.key,
    required this.batch,
    required this.rows,
    this.pdfService,
    this.textService,
  });

  final ProductionBatch batch;
  final List<ProductionConsolidationRow> rows;
  final ProductionBatchPdfService? pdfService;
  final ProductionBatchTextService? textService;

  @override
  State<ProductionBatchDetailPage> createState() =>
      _ProductionBatchDetailPageState();
}

class _ProductionBatchDetailPageState extends State<ProductionBatchDetailPage> {
  late final ProductionBatchPdfService _pdfService;
  late final ProductionBatchTextService _textService;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _pdfService = widget.pdfService ?? ProductionBatchPdfService();
    _textService = widget.textService ?? const ProductionBatchTextService();
  }

  Future<void> _export(Future<void> Function() action) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível concluir o compartilhamento.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final groups = <String, List<ProductionConsolidationRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.productKey, () => []).add(row);
    }
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    final totalWithBox = rows.fold<int>(0, (sum, row) => sum + row.withBox);
    final totalWithoutBox =
        rows.fold<int>(0, (sum, row) => sum + row.withoutBox);
    final productCount = groups.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Lote #${widget.batch.formattedId}'),
        actions: [
          IconButton(
            tooltip: 'Compartilhar texto',
            onPressed: _exporting
                ? null
                : () => _export(
                      () => _textService.share(
                        batch: widget.batch,
                        rows: rows,
                      ),
                    ),
            icon: const Icon(Icons.chat_outlined),
          ),
          IconButton(
            tooltip: 'Visualizar PDF',
            onPressed: _exporting
                ? null
                : () => _export(
                      () => _pdfService.preview(
                        batch: widget.batch,
                        rows: rows,
                      ),
                    ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Compartilhar PDF',
            onPressed: _exporting
                ? null
                : () => _export(
                      () => _pdfService.share(
                        batch: widget.batch,
                        rows: rows,
                      ),
                    ),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.dark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.neon,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 14,
                      child: _summaryItem(
                        label: 'Resumo do lote',
                        value: '$total pares',
                        crossAxisAlignment: CrossAxisAlignment.start,
                      ),
                    ),
                    const _SummaryDivider(),
                    Expanded(
                      flex: 9,
                      child: _summaryItem(
                        label: 'Com caixa',
                        value: '$totalWithBox',
                        valueColor: AppColors.neon,
                      ),
                    ),
                    const _SummaryDivider(),
                    Expanded(
                      flex: 9,
                      child: _summaryItem(
                        label: 'Sem caixa',
                        value: '$totalWithoutBox',
                        valueColor: Colors.lightBlueAccent,
                      ),
                    ),
                    const _SummaryDivider(),
                    Expanded(
                      flex: 8,
                      child: _summaryItem(
                        label: 'Produtos',
                        value: '$productCount',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...groups.values.map((group) => _groupCard(context, group)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _exporting
                    ? null
                    : () => _export(
                          () => _textService.share(
                            batch: widget.batch,
                            rows: rows,
                          ),
                        ),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Compartilhar pedido em texto'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _exporting
                    ? null
                    : () => _export(
                          () => _pdfService.share(
                            batch: widget.batch,
                            rows: rows,
                          ),
                        ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Compartilhar PDF do lote'),
              ),
            ],
          ),
          if (_exporting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String label,
    required String value,
    Color valueColor = Colors.white,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _groupCard(
    BuildContext context,
    List<ProductionConsolidationRow> group,
  ) {
    final first = group.first;
    final withBox = group.fold<int>(0, (sum, row) => sum + row.withBox);
    final withoutBox = group.fold<int>(0, (sum, row) => sum + row.withoutBox);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${first.brand} ${first.model}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text('Cor: ${first.color}'),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Text('Número', style: _headerStyle)),
                Expanded(
                  child: Text(
                    'Com caixa',
                    textAlign: TextAlign.center,
                    style: _headerStyle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total',
                    textAlign: TextAlign.end,
                    style: _headerStyle,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...group.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('${row.shoeSize}')),
                      Expanded(
                        child: Text(
                          '${row.withBox}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${row.total}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 22),
            Text(
              'Total: ${withBox + withoutBox} pares · $withBox com caixa · $withoutBox sem caixa',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  static const _headerStyle =
      TextStyle(fontWeight: FontWeight.w800, fontSize: 12);
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white12,
    );
  }
}
