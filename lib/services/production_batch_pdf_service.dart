import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/production_batch.dart';

class ProductionBatchPdfService {
  ProductionBatchPdfService({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  Future<Uint8List> buildPdf({
    required ProductionBatch batch,
    required List<ProductionConsolidationRow> rows,
  }) async {
    final document = pw.Document(
      title: 'Lote ${batch.formattedId} - MyShoes',
      author: 'MyShoes',
      creator: 'MyShoes',
    );
    final groups = _groupRows(rows);
    final totalPairs = rows.fold<int>(0, (sum, row) => sum + row.total);
    final totalWithBox = rows.fold<int>(0, (sum, row) => sum + row.withBox);
    final totalWithoutBox =
        rows.fold<int>(0, (sum, row) => sum + row.withoutBox);
    final dateTime = DateFormat('dd/MM/yyyy HH:mm');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MyShoes',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Consolidação para a fábrica',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Lote #${batch.formattedId}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    dateTime.format(batch.createdAt),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Documento gerado automaticamente pelo MyShoes',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 18),
          _summary(
            orderCount: batch.orderCount,
            productCount: groups.length,
            totalPairs: totalPairs,
            totalWithBox: totalWithBox,
            totalWithoutBox: totalWithoutBox,
          ),
          pw.SizedBox(height: 22),
          ...groups.values.map(_productGroup),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Gerado em ${dateTime.format(_now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<void> share({
    required ProductionBatch batch,
    required List<ProductionConsolidationRow> rows,
  }) async {
    final bytes = await buildPdf(batch: batch, rows: rows);
    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName(batch),
      subject: 'Lote #${batch.formattedId} - MyShoes',
    );
  }

  Future<void> preview({
    required ProductionBatch batch,
    required List<ProductionConsolidationRow> rows,
  }) async {
    await Printing.layoutPdf(
      name: fileName(batch),
      onLayout: (_) => buildPdf(batch: batch, rows: rows),
    );
  }

  String fileName(ProductionBatch batch) {
    final date = DateFormat('yyyy-MM-dd').format(batch.createdAt);
    return 'Lote_Fabrica_${batch.formattedId}_$date.pdf';
  }

  Map<String, List<ProductionConsolidationRow>> _groupRows(
    List<ProductionConsolidationRow> rows,
  ) {
    final groups = <String, List<ProductionConsolidationRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.productKey, () => []).add(row);
    }
    return groups;
  }

  pw.Widget _summary({
    required int orderCount,
    required int productCount,
    required int totalPairs,
    required int totalWithBox,
    required int totalWithoutBox,
  }) {
    final values = [
      ('Pedidos', orderCount),
      ('Produtos', productCount),
      ('Total de pares', totalPairs),
      ('Com caixa', totalWithBox),
      ('Sem caixa', totalWithoutBox),
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: values
            .map(
              (item) => pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      item.$1,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${item.$2}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  pw.Widget _productGroup(List<ProductionConsolidationRow> group) {
    final first = group.first;
    final withBox = group.fold<int>(0, (sum, row) => sum + row.withBox);
    final withoutBox = group.fold<int>(0, (sum, row) => sum + row.withoutBox);
    final total = withBox + withoutBox;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: const pw.BoxDecoration(color: PdfColors.grey800),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${first.brand} ${first.model}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Cor: ${first.color}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey200,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Número', 'Com caixa', 'Total'],
            data: group
                .map((row) => ['${row.shoeSize}', '${row.withBox}', '${row.total}'])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
            },
          ),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Text(
              'Total: $total pares  |  $withBox com caixa  |  $withoutBox sem caixa',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
