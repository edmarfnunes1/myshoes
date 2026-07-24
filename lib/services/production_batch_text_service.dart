import 'package:share_plus/share_plus.dart';

import '../models/production_batch.dart';

class ProductionBatchTextService {
  const ProductionBatchTextService();

  String buildMessage({
    required ProductionBatch batch,
    required List<ProductionConsolidationRow> rows,
  }) {
    final groups = <String, List<ProductionConsolidationRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.productKey, () => []).add(row);
    }

    final buffer = StringBuffer('Pedido:\n\n');
    final groupedRows = groups.values.toList();

    for (var index = 0; index < groupedRows.length; index++) {
      final group = [...groupedRows[index]]
        ..sort((a, b) => a.shoeSize.compareTo(b.shoeSize));
      final first = group.first;
      final productTotal = group.fold<int>(0, (sum, row) => sum + row.total);

      buffer
        ..writeln(first.brand.toUpperCase())
        ..writeln(first.model);
      if (first.color.trim().isNotEmpty) {
        buffer.writeln('Cor: ${first.color}');
      }
      buffer.writeln();

      for (final row in group) {
        buffer.writeln(_sizeLine(row));
      }

      buffer
        ..writeln()
        ..writeln('Total: $productTotal ${_pairLabel(productTotal)}');

      if (index < groupedRows.length - 1) {
        buffer
          ..writeln()
          ..writeln('--------------------')
          ..writeln();
      }
    }

    final totalPairs = rows.fold<int>(0, (sum, row) => sum + row.total);
    final totalWithBox = rows.fold<int>(0, (sum, row) => sum + row.withBox);
    final totalWithoutBox =
        rows.fold<int>(0, (sum, row) => sum + row.withoutBox);

    buffer
      ..writeln()
      ..writeln('--------------------')
      ..writeln()
      ..writeln('TOTAL DO PEDIDO')
      ..writeln()
      ..writeln('Pedidos: ${batch.orderCount}')
      ..writeln('Produtos: ${groups.length}')
      ..writeln('Total: $totalPairs ${_pairLabel(totalPairs)}')
      ..writeln('Com caixa: $totalWithBox')
      ..write('Sem caixa: $totalWithoutBox');

    return buffer.toString();
  }

  Future<void> share({
    required ProductionBatch batch,
    required List<ProductionConsolidationRow> rows,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: buildMessage(batch: batch, rows: rows),
        subject: 'Pedido',
      ),
    );
  }

  String _sizeLine(ProductionConsolidationRow row) {
    final parts = <String>[];
    if (row.withBox > 0) {
      parts.add('${row.withBox} com caixa');
    }
    if (row.withoutBox > 0) {
      parts.add('${row.withoutBox} sem caixa');
    }
    return '${row.shoeSize} - ${parts.join(' / ')}';
  }

  String _pairLabel(int quantity) => quantity == 1 ? 'par' : 'pares';
}
