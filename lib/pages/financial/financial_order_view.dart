import '../../models/order.dart';

enum FinancialOrderSort {
  newest,
  oldest,
  highestValue,
  lowestValue,
  pendingFirst,
  partialFirst,
}

List<Order> filterAndSortFinancialOrders({
  required Iterable<Order> orders,
  String search = '',
  FinancialOrderSort sort = FinancialOrderSort.newest,
}) {
  final normalizedSearch = search.trim().toLowerCase();
  final idSearch = normalizedSearch.startsWith('#')
      ? normalizedSearch.substring(1).trim()
      : normalizedSearch;

  final result = orders.where((order) {
    if (normalizedSearch.isEmpty) return true;

    final matchesCustomer =
        order.customerName.toLowerCase().contains(normalizedSearch);
    final matchesId = order.id?.toString() == idSearch;
    return matchesCustomer || matchesId;
  }).toList();

  result.sort((a, b) {
    return switch (sort) {
      FinancialOrderSort.newest => _compareDateDescending(a, b),
      FinancialOrderSort.oldest => _compareDateAscending(a, b),
      FinancialOrderSort.highestValue =>
        _compareDoubleDescending(a.totalValue, b.totalValue, a, b),
      FinancialOrderSort.lowestValue =>
        _compareDoubleAscending(a.totalValue, b.totalValue, a, b),
      FinancialOrderSort.pendingFirst =>
        _compareByPriority(a, b, const ['pendente', 'parcial', 'pago']),
      FinancialOrderSort.partialFirst =>
        _compareByPriority(a, b, const ['parcial', 'pendente', 'pago']),
    };
  });

  return result;
}

String financialOrderItemsSummary(Order order) {
  if (order.items.isEmpty) return 'Sem itens';

  return order.items.map((item) {
    final name = item.productName?.trim();
    final product = name == null || name.isEmpty ? 'Tênis' : name;
    return '${item.quantity} $product';
  }).join(' • ');
}

int _compareDateDescending(Order a, Order b) {
  final dateComparison = _dateValue(b).compareTo(_dateValue(a));
  return dateComparison != 0 ? dateComparison : _compareIdDescending(a, b);
}

int _compareDateAscending(Order a, Order b) {
  final dateComparison = _dateValue(a).compareTo(_dateValue(b));
  return dateComparison != 0 ? dateComparison : _compareIdAscending(a, b);
}

int _compareDoubleDescending(double a, double b, Order first, Order second) {
  final comparison = b.compareTo(a);
  return comparison != 0 ? comparison : _compareDateDescending(first, second);
}

int _compareDoubleAscending(double a, double b, Order first, Order second) {
  final comparison = a.compareTo(b);
  return comparison != 0 ? comparison : _compareDateDescending(first, second);
}

int _compareByPriority(
  Order a,
  Order b,
  List<String> priority,
) {
  final aIndex = priority.indexOf(_normalizedStatus(a));
  final bIndex = priority.indexOf(_normalizedStatus(b));
  final comparison = aIndex.compareTo(bIndex);
  return comparison != 0 ? comparison : _compareDateDescending(a, b);
}

String _normalizedStatus(Order order) {
  return switch (order.paymentStatus?.trim().toLowerCase()) {
    'pago' => 'pago',
    'parcial' => 'parcial',
    _ => 'pendente',
  };
}

DateTime _dateValue(Order order) =>
    order.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

int _compareIdDescending(Order a, Order b) =>
    (b.id ?? -1).compareTo(a.id ?? -1);

int _compareIdAscending(Order a, Order b) =>
    (a.id ?? -1).compareTo(b.id ?? -1);
