import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_page_header.dart';
import '../orders/order_form_page.dart';
import 'financial_order_view.dart';
import 'financial_summary.dart';

enum FinancialPeriod { today, yesterday, thisWeek, thisMonth, lastMonth, custom }

const _visibleFinancialPeriods = <FinancialPeriod>[
  FinancialPeriod.thisWeek,
  FinancialPeriod.thisMonth,
  FinancialPeriod.lastMonth,
  FinancialPeriod.custom,
];

class FinancialDashboardPage extends StatefulWidget {
  const FinancialDashboardPage({
    super.key,
    this.repository,
    this.refreshToken = 0,
    this.formPageBuilder,
  });

  final OrderRepository? repository;
  final int refreshToken;
  final Widget Function(Order order)? formPageBuilder;

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage> {
  late final OrderRepository _repository;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);

  FinancialPeriod _selectedPeriod = FinancialPeriod.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;
  final _searchController = TextEditingController();

  List<Order> _orders = const [];
  FinancialOrderSort _sort = FinancialOrderSort.newest;
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OrderRepository();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FinancialDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final orders = await _repository.findAll();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _orders = const [];
        _loadError = error;
        _loading = false;
      });
    }
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTimeRange get _activeRange {
    final today = _dateOnly(DateTime.now());
    return switch (_selectedPeriod) {
      FinancialPeriod.today => DateTimeRange(start: today, end: today),
      FinancialPeriod.yesterday => DateTimeRange(
          start: today.subtract(const Duration(days: 1)),
          end: today.subtract(const Duration(days: 1)),
        ),
      FinancialPeriod.thisWeek => DateTimeRange(
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: today,
        ),
      FinancialPeriod.thisMonth => DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: today,
        ),
      FinancialPeriod.lastMonth => _lastMonthRange(today),
      FinancialPeriod.custom => DateTimeRange(
          start: _customStart ?? today,
          end: _customEnd ?? _customStart ?? today,
        ),
    };
  }

  DateTimeRange _lastMonthRange(DateTime today) {
    final firstThisMonth = DateTime(today.year, today.month, 1);
    final end = firstThisMonth.subtract(const Duration(days: 1));
    return DateTimeRange(start: DateTime(end.year, end.month, 1), end: end);
  }

  List<Order> get _filteredOrders {
    final range = _activeRange;
    return _orders.where((order) {
      final createdAt = order.createdAt;
      if (createdAt == null) return false;
      final date = _dateOnly(createdAt);
      return !date.isBefore(range.start) && !date.isAfter(range.end);
    }).toList();
  }

  List<Order> get _visibleOrders => filterAndSortFinancialOrders(
        orders: _filteredOrders,
        search: _searchController.text,
        sort: _sort,
      );

  FinancialSummary get _financialSummary =>
      FinancialSummary.fromOrders(_filteredOrders);

  Future<void> _selectPeriod(FinancialPeriod period) async {
    if (period == FinancialPeriod.custom) {
      final today = _dateOnly(DateTime.now());
      final selected = await showDateRangePicker(
        context: context,
        initialDateRange: DateTimeRange(
          start: _customStart ?? today,
          end: _customEnd ?? today,
        ),
        firstDate: DateTime(2020),
        lastDate: DateTime(today.year + 10),
        helpText: 'Selecionar período',
        cancelText: 'Cancelar',
        confirmText: 'Aplicar',
        saveText: 'Aplicar',
      );
      if (selected == null || !mounted) return;
      setState(() {
        _selectedPeriod = period;
        _customStart = _dateOnly(selected.start);
        _customEnd = _dateOnly(selected.end);
      });
      return;
    }
    setState(() => _selectedPeriod = period);
  }

  Future<void> _editCustomDate({required bool start}) async {
    final today = _dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? (_customStart ?? today) : (_customEnd ?? _customStart ?? today),
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 10),
      helpText: start ? 'Selecionar data inicial' : 'Selecionar data final',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (selected == null || !mounted) return;
    final date = _dateOnly(selected);
    setState(() {
      _selectedPeriod = FinancialPeriod.custom;
      if (start) {
        _customStart = date;
        if (_customEnd != null && _customEnd!.isBefore(date)) _customEnd = date;
      } else {
        _customEnd = date;
        if (_customStart != null && _customStart!.isAfter(date)) _customStart = date;
      }
    });
  }

  Future<void> _openOrder(Order order) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            widget.formPageBuilder?.call(order) ?? OrderFormPage(order: order),
      ),
    );
    if (saved != true) return;

    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          order.isInProductionBatch
              ? 'Pagamento atualizado com sucesso.'
              : 'Pedido atualizado com sucesso.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: AppPageHeader(
                  title: 'Painel Financeiro',
                  subtitle: 'Acompanhe vendas e recebimentos',
                ),
              ),
              SliverToBoxAdapter(child: _filters()),
              SliverToBoxAdapter(child: _summary()),
              SliverToBoxAdapter(child: _paymentStatusSummary()),
              SliverToBoxAdapter(child: _ordersHeader()),
              SliverToBoxAdapter(child: _searchAndSort()),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    key: ValueKey('financial-loading-state'),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_loadError != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _errorState(),
                )
              else if (_filteredOrders.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState())
              else if (_visibleOrders.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptySearchState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: _visibleOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _orderCard(_visibleOrders[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Período'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _visibleFinancialPeriods.map((period) {
              final selected = _selectedPeriod == period;
              return ChoiceChip(
                key: ValueKey('financial-period-${period.name}'),
                label: Text(_periodLabel(period)),
                selected: selected,
                onSelected: (_) => _selectPeriod(period),
                selectedColor: AppColors.neon,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? AppColors.dark : const Color(0xFFD8DEE8),
                  width: selected ? 1.2 : 1,
                ),
                labelStyle: TextStyle(
                  color: AppColors.dark,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              );
            }).toList(),
          ),
          if (_selectedPeriod == FinancialPeriod.custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dateField(
                    label: 'Data inicial',
                    date: _customStart,
                    onTap: () => _editCustomDate(start: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateField(
                    label: 'Data final',
                    date: _customEnd,
                    onTap: () => _editCustomDate(start: false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateField({required String label, required DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8DEE8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    date == null ? 'Selecionar' : _dateFormat.format(date),
                    style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    final summary = _financialSummary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Resumo do período')),
              Text(
                '${_dateFormat.format(_activeRange.start)} a ${_dateFormat.format(_activeRange.end)}',
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryCard(title: 'Recebido', value: _currency.format(summary.received), icon: Icons.payments_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard(title: 'Pendente', value: _currency.format(summary.pending), icon: Icons.schedule_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryCard(title: 'Total em vendas', value: _currency.format(summary.totalSales), icon: Icons.shopping_bag_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard(title: 'Pedidos', value: summary.orders.toString(), icon: Icons.receipt_long_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryCard(title: 'Custo dos tênis', value: _currency.format(summary.shoeCost), icon: Icons.shopping_bag_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard(title: 'Custo das caixas', value: _currency.format(summary.boxCost), icon: Icons.inventory_2_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryCard(title: 'Custo total', value: _currency.format(summary.totalCost), icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard(title: 'Lucro', value: _currency.format(summary.profit), icon: Icons.trending_up)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({required String title, required String value, required IconData icon}) {
    return Container(
      key: ValueKey('financial-summary-${title.toLowerCase().replaceAll(' ', '-')}'),
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8DEE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.dark, size: 22),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(color: Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
            value,
            key: ValueKey(
              'financial-summary-value-${title.toLowerCase().replaceAll(' ', '-')}',
            ),
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          ),
        ],
      ),
    );
  }


  Widget _paymentStatusSummary() {
    final summary = _financialSummary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Situação dos pagamentos'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD8DEE8)),
            ),
            child: Column(
              children: [
                _paymentStatusLine(
                  key: const ValueKey('financial-status-paid'),
                  label: 'Pago',
                  count: summary.paidOrders,
                ),
                const Divider(height: 1),
                _paymentStatusLine(
                  key: const ValueKey('financial-status-partial'),
                  label: 'Parcial',
                  count: summary.partialOrders,
                ),
                const Divider(height: 1),
                _paymentStatusLine(
                  key: const ValueKey('financial-status-pending'),
                  label: 'Pendente',
                  count: summary.pendingOrders,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentStatusLine({
    required Key key,
    required String label,
    required int count,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.dark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            count.toString(),
            key: ValueKey('financial-status-${label.toLowerCase()}-count'),
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: _sectionTitle('Pedidos do período'),
    );
  }


  Widget _searchAndSort() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('financial-order-search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar cliente ou número do pedido',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('financial-order-search-clear'),
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.dark, width: 1.2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<FinancialOrderSort>(
            key: const ValueKey('financial-order-sort'),
            tooltip: 'Ordenar pedidos',
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (_) => FinancialOrderSort.values
                .map(
                  (sort) => PopupMenuItem(
                    value: sort,
                    child: Row(
                      children: [
                        if (_sort == sort) ...[
                          const Icon(Icons.check, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(_sortLabel(sort)),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD8DEE8)),
              ),
              child: const Icon(Icons.swap_vert, color: AppColors.dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Order order) {
    final received = switch (order.paymentStatus) {
      'Pago' => order.totalValue,
      'Parcial' => order.amountPaid.clamp(0, order.totalValue).toDouble(),
      _ => 0.0,
    };
    final pending = (order.totalValue - received)
        .clamp(0, double.infinity)
        .toDouble();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('financial-order-${order.id}'),
        onTap: () => _openOrder(order),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8DEE8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order.customerName, style: const TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w800))),
                  _paymentChip(order.paymentStatus),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFF667085)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Pedido #${order.id ?? '-'} • ${_dateFormat.format(order.createdAt ?? DateTime.now())}',
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Text(
                financialOrderItemsSummary(order),
                key: ValueKey('financial-order-items-${order.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _moneyLine('Venda', order.totalValue)),
                  Expanded(child: _moneyLine('Recebido', received)),
                  Expanded(child: _moneyLine('Saldo', pending)),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(child: _moneyLine('Tênis', order.shoeCost)),
                  Expanded(child: _moneyLine('Caixas', order.boxCost)),
                  Expanded(child: _moneyLine('Custo total', order.totalCost)),
                ],
              ),
              const SizedBox(height: 12),
              _moneyLine('Lucro', order.profit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moneyLine(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_currency.format(value), style: const TextStyle(color: AppColors.dark, fontSize: 14, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _paymentChip(String? status) {
    final label = status?.trim().isNotEmpty == true ? status! : 'Pendente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: label == 'Pago' ? AppColors.neon : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.dark),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.dark, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _emptyState() {
    return Padding(
      key: const ValueKey('financial-empty-period-state'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 52, color: Color(0xFF98A2B3)),
          const SizedBox(height: 14),
          const Text('Nenhum pedido encontrado para o período selecionado.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.dark, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Selecione outro período para visualizar os pedidos e valores.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF667085)),
          ),
        ],
      ),
    );
  }


  Widget _emptySearchState() {
    return Padding(
      key: const ValueKey('financial-empty-search-state'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_outlined, size: 52, color: Color(0xFF98A2B3)),
          const SizedBox(height: 14),
          const Text(
            'Nenhum pedido encontrado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Não encontramos resultados para a busca dentro do período selecionado.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF667085)),
          ),
        ],
      ),
    );
  }


  Widget _errorState() {
    return Padding(
      key: const ValueKey('financial-error-state'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 52,
            color: Color(0xFF98A2B3),
          ),
          const SizedBox(height: 14),
          const Text(
            'Não foi possível carregar os dados financeiros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verifique os dados e tente novamente.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF667085)),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const ValueKey('financial-error-retry'),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w900));

  String _sortLabel(FinancialOrderSort sort) => switch (sort) {
        FinancialOrderSort.newest => 'Mais recentes',
        FinancialOrderSort.oldest => 'Mais antigos',
        FinancialOrderSort.highestValue => 'Maior valor',
        FinancialOrderSort.lowestValue => 'Menor valor',
        FinancialOrderSort.pendingFirst => 'Pendentes primeiro',
        FinancialOrderSort.partialFirst => 'Parciais primeiro',
      };

  String _periodLabel(FinancialPeriod period) => switch (period) {
        FinancialPeriod.today => 'Hoje',
        FinancialPeriod.yesterday => 'Ontem',
        FinancialPeriod.thisWeek => 'Esta semana',
        FinancialPeriod.thisMonth => 'Este mês',
        FinancialPeriod.lastMonth => 'Mês passado',
        FinancialPeriod.custom => 'Personalizado',
      };
}
