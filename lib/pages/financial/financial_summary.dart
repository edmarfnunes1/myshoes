import '../../models/order.dart';

class FinancialSummary {
  const FinancialSummary({
    required this.received,
    required this.pending,
    required this.totalSales,
    required this.shoeCost,
    required this.boxCost,
    required this.totalCost,
    required this.profit,
    required this.orders,
    required this.paidOrders,
    required this.partialOrders,
    required this.pendingOrders,
  });

  final double received;
  final double pending;
  final double totalSales;
  final double shoeCost;
  final double boxCost;
  final double totalCost;
  final double profit;
  final int orders;
  final int paidOrders;
  final int partialOrders;
  final int pendingOrders;

  factory FinancialSummary.fromOrders(Iterable<Order> orders) {
    var received = 0.0;
    var totalSales = 0.0;
    var shoeCost = 0.0;
    var boxCost = 0.0;
    var orderCount = 0;
    var paidOrders = 0;
    var partialOrders = 0;
    var pendingOrders = 0;

    for (final order in orders) {
      orderCount++;
      totalSales += order.totalValue;
      shoeCost += order.shoeCost;
      boxCost += order.boxCost;

      switch (_normalizePaymentStatus(order.paymentStatus)) {
        case _PaymentStatus.paid:
          paidOrders++;
          received += order.totalValue;
        case _PaymentStatus.partial:
          partialOrders++;
          received += order.amountPaid.clamp(0, order.totalValue).toDouble();
        case _PaymentStatus.pending:
          pendingOrders++;
      }
    }

    final totalCost = shoeCost + boxCost;
    return FinancialSummary(
      received: received,
      pending: (totalSales - received).clamp(0, double.infinity).toDouble(),
      totalSales: totalSales,
      shoeCost: shoeCost,
      boxCost: boxCost,
      totalCost: totalCost,
      profit: totalSales - totalCost,
      orders: orderCount,
      paidOrders: paidOrders,
      partialOrders: partialOrders,
      pendingOrders: pendingOrders,
    );
  }
}

enum _PaymentStatus { paid, partial, pending }

_PaymentStatus _normalizePaymentStatus(String? status) {
  switch (status?.trim().toLowerCase()) {
    case 'pago':
      return _PaymentStatus.paid;
    case 'parcial':
      return _PaymentStatus.partial;
    default:
      return _PaymentStatus.pending;
  }
}
