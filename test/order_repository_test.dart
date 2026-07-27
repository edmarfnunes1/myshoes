import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshoes/data/app_database.dart';
import 'package:myshoes/data/order_repository.dart';
import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';
import 'package:myshoes/models/product.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late OrderRepository orderRepository;
  late ProductRepository productRepository;
  late Product product;
  late Product secondProduct;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myshoes_order_repository_test_',
    );
    databasePath = '${temporaryDirectory.path}/myshoes_test.db';
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    orderRepository = OrderRepository(database: appDatabase);
    productRepository = ProductRepository(database: appDatabase);

    product = await productRepository.save(
      const Product(
        brand: 'Nike',
        model: 'N1',
        minimumSize: 34,
        maximumSize: 44,
        costPrice: 100,
        salePrice: 180,
      ),
    );
    secondProduct = await productRepository.save(
      const Product(
        brand: 'Adidas',
        model: 'A1',
        minimumSize: 33,
        maximumSize: 43,
        costPrice: 120,
        salePrice: 220,
      ),
    );
  });

  tearDown(() async {
    await appDatabase.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  OrderItem item({
    int? productId,
    int shoeSize = 38,
    String? color = 'Preto',
    int quantity = 1,
    bool withBox = false,
    double unitPrice = 180,
  }) {
    return OrderItem(
      productId: productId ?? product.id!,
      shoeSize: shoeSize,
      color: color,
      quantity: quantity,
      withBox: withBox,
      unitPrice: unitPrice,
    );
  }

  Future<Order> saveOrder({
    String customerName = 'Ana',
    String? customerPhone = '44999990000',
    String paymentStatus = 'Pendente',
    String? notes = 'Pedido de teste',
    DateTime? createdAt,
    List<OrderItem>? items,
  }) async {
    await orderRepository.save(
      Order(
        customerName: customerName,
        customerPhone: customerPhone,
        paymentStatus: paymentStatus,
        notes: notes,
        createdAt: createdAt ?? DateTime(2026, 7, 27),
        items: items ?? [item()],
      ),
    );

    final orders = await orderRepository.findAll();
    return orders.singleWhere(
      (order) => order.customerName == customerName,
    );
  }

  Future<int> sendToFactory(int orderId) async {
    final database = await appDatabase.database;
    final batchId = await database.insert(
      'production_batches',
      {'created_at': '2026-07-27'},
    );
    await database.insert(
      'production_batch_orders',
      {'batch_id': batchId, 'order_id': orderId},
    );
    return batchId;
  }

  group('OrderRepository', () {
    test('salva pedido com os dados principais', () async {
      final saved = await saveOrder();

      expect(saved.id, isNotNull);
      expect(saved.customerName, 'Ana');
      expect(saved.customerPhone, '44999990000');
      expect(saved.paymentStatus, 'Pendente');
      expect(saved.notes, 'Pedido de teste');
      expect(saved.createdAt, DateTime(2026, 7, 27));
    });

    test('atualiza pedido e substitui os itens anteriores', () async {
      final saved = await saveOrder(
        items: [item(shoeSize: 37, quantity: 1)],
      );

      await orderRepository.save(
        Order(
          id: saved.id,
          customerName: 'Ana atualizada',
          customerPhone: '44888880000',
          paymentStatus: 'Pago',
          notes: 'Atualizado',
          createdAt: saved.createdAt,
          items: [
            item(
              productId: secondProduct.id,
              shoeSize: 40,
              color: 'Branco',
              quantity: 3,
              withBox: true,
              unitPrice: 220,
            ),
          ],
        ),
      );

      final updated = await orderRepository.findById(saved.id!);

      expect(updated, isNotNull);
      expect(updated!.customerName, 'Ana atualizada');
      expect(updated.customerPhone, '44888880000');
      expect(updated.paymentStatus, 'Pago');
      expect(updated.notes, 'Atualizado');
      expect(updated.createdAt, saved.createdAt);
      expect(updated.items, hasLength(1));
      expect(updated.items.single.productId, secondProduct.id);
      expect(updated.items.single.shoeSize, 40);
      expect(updated.items.single.quantity, 3);
      expect(updated.items.single.withBox, isTrue);
    });

    test('exclui pedido', () async {
      final saved = await saveOrder();

      await orderRepository.delete(saved.id!);

      expect(await orderRepository.findById(saved.id!), isNull);
      expect(await orderRepository.findAll(), isEmpty);
    });

    test('busca pedido por ID com seus itens', () async {
      final saved = await saveOrder(
        items: [
          item(shoeSize: 36),
          item(
            productId: secondProduct.id,
            shoeSize: 41,
            color: 'Azul',
          ),
        ],
      );

      final found = await orderRepository.findById(saved.id!);

      expect(found, isNotNull);
      expect(found!.id, saved.id);
      expect(found.items, hasLength(2));
      expect(found.items.map((value) => value.productName), [
        'Nike N1',
        'Adidas A1',
      ]);
    });

    test('retorna nulo ao buscar ID inexistente', () async {
      expect(await orderRepository.findById(999999), isNull);
    });

    test('lista todos os pedidos', () async {
      await saveOrder(customerName: 'Ana');
      await saveOrder(customerName: 'Bruno');
      await saveOrder(customerName: 'Carla');

      final orders = await orderRepository.findAll();

      expect(orders, hasLength(3));
      expect(
        orders.map((order) => order.customerName),
        containsAll(['Ana', 'Bruno', 'Carla']),
      );
    });

    test('permite filtrar a lista por status de pagamento', () async {
      await saveOrder(customerName: 'Ana', paymentStatus: 'Pago');
      await saveOrder(customerName: 'Bruno', paymentStatus: 'Pendente');
      await saveOrder(customerName: 'Carla', paymentStatus: 'Pago');

      final orders = await orderRepository.findAll();
      final paidOrders = orders
          .where((order) => order.paymentStatus == 'Pago')
          .toList();

      expect(paidOrders, hasLength(2));
      expect(
        paidOrders.map((order) => order.customerName),
        containsAll(['Ana', 'Carla']),
      );
    });

    test('ordena por data decrescente e nome crescente no mesmo dia', () async {
      await saveOrder(
        customerName: 'Carlos',
        createdAt: DateTime(2026, 7, 26),
      );
      await saveOrder(
        customerName: 'Bruno',
        createdAt: DateTime(2026, 7, 27),
      );
      await saveOrder(
        customerName: 'Ana',
        createdAt: DateTime(2026, 7, 27),
      );

      final orders = await orderRepository.findAll();

      expect(
        orders.map((order) => order.customerName).toList(),
        ['Ana', 'Bruno', 'Carlos'],
      );
    });

    test('persiste todos os campos dos itens', () async {
      final saved = await saveOrder(
        items: [
          item(
            shoeSize: 39,
            color: 'Verde',
            quantity: 2,
            withBox: true,
            unitPrice: 199.90,
          ),
          item(
            productId: secondProduct.id,
            shoeSize: 42,
            color: null,
            quantity: 1,
            withBox: false,
            unitPrice: 249.50,
          ),
        ],
      );

      final found = await orderRepository.findById(saved.id!);

      expect(found!.items, hasLength(2));
      expect(found.items[0].orderId, saved.id);
      expect(found.items[0].shoeSize, 39);
      expect(found.items[0].color, 'Verde');
      expect(found.items[0].quantity, 2);
      expect(found.items[0].withBox, isTrue);
      expect(found.items[0].unitPrice, 199.90);
      expect(found.items[1].productId, secondProduct.id);
      expect(found.items[1].color, isNull);
    });

    test('exclui os itens em cascata ao excluir o pedido', () async {
      final saved = await saveOrder(
        items: [item(), item(productId: secondProduct.id)],
      );
      final database = await appDatabase.database;

      await orderRepository.delete(saved.id!);

      final itemRows = await database.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [saved.id],
      );
      expect(itemRows, isEmpty);
    });

    test('identifica pedido enviado para a fábrica e informa o lote', () async {
      final saved = await saveOrder();
      final batchId = await sendToFactory(saved.id!);

      final found = await orderRepository.findById(saved.id!);
      final listed = await orderRepository.findAll();

      expect(found!.isInProductionBatch, isTrue);
      expect(found.productionBatchId, batchId);
      expect(listed.single.productionBatchId, batchId);
    });

    test('impede editar pedido enviado para a fábrica', () async {
      final saved = await saveOrder();
      await sendToFactory(saved.id!);

      final operation = orderRepository.save(
        Order(
          id: saved.id,
          customerName: 'Alteração proibida',
          createdAt: saved.createdAt,
          items: saved.items,
        ),
      );

      await expectLater(
        operation,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('não pode ser editado'),
          ),
        ),
      );
    });

    test('impede excluir pedido enviado para a fábrica', () async {
      final saved = await saveOrder();
      await sendToFactory(saved.id!);

      await expectLater(
        orderRepository.delete(saved.id!),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('não pode ser excluído'),
          ),
        ),
      );
      expect(await orderRepository.findById(saved.id!), isNotNull);
    });

    test('altera o status de pagamento', () async {
      final saved = await saveOrder(paymentStatus: 'Pendente');

      await orderRepository.save(
        Order(
          id: saved.id,
          customerName: saved.customerName,
          customerPhone: saved.customerPhone,
          items: saved.items,
          paymentStatus: 'Pago',
          notes: saved.notes,
          createdAt: saved.createdAt,
        ),
      );

      final updated = await orderRepository.findById(saved.id!);
      expect(updated!.paymentStatus, 'Pago');
    });

    test('calcula quantidade e valor total dos itens persistidos', () async {
      final saved = await saveOrder(
        items: [
          item(quantity: 2, unitPrice: 150),
          item(
            productId: secondProduct.id,
            quantity: 3,
            unitPrice: 200,
          ),
        ],
      );

      final found = await orderRepository.findById(saved.id!);

      expect(found!.totalQuantity, 5);
      expect(found.totalValue, 900);
    });

    test('não exclui outros pedidos ao remover um pedido', () async {
      final first = await saveOrder(customerName: 'Ana');
      final second = await saveOrder(customerName: 'Bruno');

      await orderRepository.delete(first.id!);

      expect(await orderRepository.findById(first.id!), isNull);
      expect(await orderRepository.findById(second.id!), isNotNull);
    });

    test('salva pedido sem itens', () async {
      final saved = await saveOrder(items: const []);

      final found = await orderRepository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.items, isEmpty);
      expect(found.totalQuantity, 0);
      expect(found.totalValue, 0);
    });
  });
}
