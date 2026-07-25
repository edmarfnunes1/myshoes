import 'package:share_plus/share_plus.dart';

import '../models/production_batch.dart';

class ProductionBatchTextService {
  const ProductionBatchTextService();

  String buildMessage({
    required ProductionBatch batch,
    required List<ProductionConsolidationRow> rows,
  }) {
    final orderedRows=[...rows]..sort((a,b){
      var c=a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
      if(c!=0)return c;
      c=a.model.toLowerCase().compareTo(b.model.toLowerCase());
      if(c!=0)return c;
      c=a.shoeSize.compareTo(b.shoeSize);
      if(c!=0)return c;
      return a.color.toLowerCase().compareTo(b.color.toLowerCase());
    });
    final buffer=StringBuffer('Pedido:\n\n');
    for(final row in orderedRows){
      if(row.withBox>0){
        buffer.writeln(_buildLine(quantity:row.withBox,brand:row.brand,model:row.model,size:row.shoeSize,color:row.color,withBox:true));
      }
      if(row.withoutBox>0){
        buffer.writeln(_buildLine(quantity:row.withoutBox,brand:row.brand,model:row.model,size:row.shoeSize,color:row.color,withBox:false));
      }
    }
    final totalPairs=rows.fold<int>(0,(s,r)=>s+r.total);
    final totalWithBox=rows.fold<int>(0,(s,r)=>s+r.withBox);
    final totalWithoutBox=rows.fold<int>(0,(s,r)=>s+r.withoutBox);
    buffer
      ..writeln()
      ..writeln('------')
      ..writeln('TOTAL DO PEDIDO')
      ..writeln()
      ..writeln('Total: $totalPairs ${_pairLabel(totalPairs)}')
      ..writeln('Com caixa: $totalWithBox')
      ..write('Sem caixa: $totalWithoutBox');
    return buffer.toString();
  }

  Future<void> share({required ProductionBatch batch,required List<ProductionConsolidationRow> rows}) async{
    await SharePlus.instance.share(ShareParams(text:buildMessage(batch:batch,rows:rows),subject:'Pedido'));
  }

  String _buildLine({required int quantity,required String brand,required String model,required int size,required String color,required bool withBox}){
    final parts=<String>[quantity.toString(),brand,model,'N:$size'];
    final normalizedColor = color.trim();
    final hasColor = normalizedColor.isNotEmpty &&
        normalizedColor.toLowerCase() != 'sem cor';

    if (hasColor) {
      parts.add('Cor: $normalizedColor');
    }
    parts.add(withBox?'C.Caixa':'S.Caixa');
    return parts.join(' ');
  }

  String _pairLabel(int quantity)=>quantity==1?'par':'pares';
}
