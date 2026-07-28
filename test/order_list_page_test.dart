import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshoes/data/order_repository.dart';
import 'package:myshoes/data/product_repository.dart';
import 'package:myshoes/models/order.dart';
import 'package:myshoes/models/order_item.dart';
import 'package:myshoes/models/product.dart';
import 'package:myshoes/models/product_image.dart';
import 'package:myshoes/pages/orders/order_list_page.dart';
import 'package:myshoes/pages/product_image_gallery_page.dart';

class FakeOrderRepository extends OrderRepository {
  FakeOrderRepository({this.orders = const []});

  List<Order> orders;
  final List<String> searches = [];
  int? deletedId;

  @override
  Future<List<Order>> findAll({String search = ''}) async {
    searches.add(search);
    final normalized = search.trim().toLowerCase();
    if (normalized.isEmpty) return orders;
    return orders.where((order) {
      final id = order.id?.toString() ?? '';
      final date = order.createdAt == null
          ? ''
          : '${order.createdAt!.day.toString().padLeft(2, '0')}/'
              '${order.createdAt!.month.toString().padLeft(2, '0')}/'
              '${order.createdAt!.year}';
      return order.customerName.toLowerCase().contains(normalized) ||
          id.contains(normalized.replaceAll('#', '')) ||
          date.contains(normalized);
    }).toList();
  }

  @override
  Future<void> delete(int id) async {
    deletedId = id;
    orders = orders.where((order) => order.id != id).toList();
  }
}

class FakeProductRepository extends ProductRepository {
  FakeProductRepository({this.productsById = const {}});

  final Map<int, Product> productsById;

  @override
  Future<Product?> findByIdWithImages(int id) async => productsById[id];
}

void main() {
  Order sampleOrder({
    int id = 1,
    String customerName = 'Ana Paula',
    String? paymentStatus = 'Pendente',
    String? color = 'Preto',
    DateTime? createdAt,
    bool withBox = false,
    int? productionBatchId,
  }) =>
      Order(
        id: id,
        customerName: customerName,
        customerPhone: '44999990000',
        paymentStatus: paymentStatus,
        notes: 'Entregar no centro',
        createdAt: createdAt ?? DateTime(2026, 7, 23),
        items: [
          OrderItem(
            productId: 1,
            shoeSize: 38,
            color: color,
            quantity: 2,
            withBox: withBox,
            unitPrice: 150,
            productName: 'Nike Air Max',
          ),
        ],
        productionBatchId: productionBatchId,
      );

  Future<void> pumpPage(
    WidgetTester tester, {
    required FakeOrderRepository repository,
    Widget Function(Order? order)? formPageBuilder,
    FakeProductRepository? productRepository,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderListPage(
          repository: repository,
          formPageBuilder: formPageBuilder,
          productRepository: productRepository ?? FakeProductRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exibe estado vazio e ações para cadastrar', (tester) async {
    await pumpPage(tester, repository: FakeOrderRepository());

    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Nenhum pedido em andamento.'), findsOneWidget);
    expect(find.text('Cadastrar pedido'), findsOneWidget);
    expect(find.text('Novo pedido'), findsOneWidget);
  });

  testWidgets('exibe ID, data, cor, quantidade, total e status no card',
      (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(orders: [sampleOrder(id: 15)]),
    );

    expect(find.text('Pedido #0015'), findsOneWidget);
    expect(find.text('23/07/2026'), findsOneWidget);
    expect(find.text('ANA PAULA'), findsOneWidget);
    expect(
      find.text('Nike Air Max · Nº 38 · Cor: Preto · Qtd. 2 · S.Caixa'),
      findsOneWidget,
    );
    expect(find.text('2 tênis'), findsOneWidget);
    expect(find.text('Pagamento'), findsOneWidget);
    expect(find.text('Pagamento total'), findsOneWidget);
    expect(find.text('R\$\u00a0300,00'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
  });

  testWidgets('omite a cor da descrição quando não foi informada',
      (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(
        orders: [sampleOrder(color: null)],
      ),
    );

    expect(find.text('Nike Air Max · Nº 38 · Qtd. 2 · S.Caixa'), findsOneWidget);
    expect(find.textContaining('Cor:'), findsNothing);
  });


  testWidgets('exibe C.Caixa quando o item possui caixa', (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(
        orders: [sampleOrder(withBox: true)],
      ),
    );

    expect(
      find.text('Nike Air Max · Nº 38 · Cor: Preto · Qtd. 2 · C.Caixa'),
      findsOneWidget,
    );
    expect(find.textContaining('S.Caixa'), findsNothing);
  });

  testWidgets('exibe status Em lote e opção de atualizar pagamento', (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(
        orders: [sampleOrder(productionBatchId: 12)],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();

    expect(find.text('Lote #0012'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Atualizar pagamento'), findsOneWidget);
  });

  testWidgets('pedido em lote abre formulário para atualizar pagamento', (tester) async {
    var formOpened = false;
    await pumpPage(
      tester,
      repository: FakeOrderRepository(
        orders: [sampleOrder(id: 9, productionBatchId: 4)],
      ),
      formPageBuilder: (_) {
        formOpened = true;
        return const Scaffold(body: Text('Edição indevida'));
      },
    );
    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedido #0009'));
    await tester.pumpAndSettle();

    expect(formOpened, isTrue);
    expect(find.text('Edição indevida'), findsOneWidget);
  });

  testWidgets('menu do pedido em lote oferece apenas atualizar pagamento',
      (tester) async {
    final repository = FakeOrderRepository(
      orders: [sampleOrder(productionBatchId: 3)],
    );
    await pumpPage(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(repository.deletedId, isNull);
    expect(find.text('Atualizar pagamento'), findsOneWidget);
    expect(find.text('Excluir'), findsNothing);
  });

  testWidgets('normaliza status vazio para Pendente', (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(
        orders: [sampleOrder(paymentStatus: '  ', productionBatchId: 7)],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();

    expect(find.text('Pendente'), findsOneWidget);
  });

  testWidgets('filtra pedidos após digitar na busca', (tester) async {
    final repository = FakeOrderRepository(
      orders: [
        sampleOrder(customerName: 'Ana Paula'),
        sampleOrder(id: 2, customerName: 'Bruno Souza'),
      ],
    );
    await pumpPage(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'Bruno');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.searches, contains('Bruno'));
    expect(find.text('BRUNO SOUZA'), findsOneWidget);
    expect(find.text('ANA PAULA'), findsNothing);
  });

  testWidgets('pesquisa por ID com cerquilha', (tester) async {
    final repository = FakeOrderRepository(
      orders: [sampleOrder(id: 15), sampleOrder(id: 27)],
    );
    await pumpPage(tester, repository: repository);

    await tester.enterText(find.byType(TextField), '#27');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Pedido #0027'), findsOneWidget);
    expect(find.text('Pedido #0015'), findsNothing);
  });

  testWidgets('exibe estado de busca sem resultado', (tester) async {
    final repository = FakeOrderRepository(orders: [sampleOrder()]);
    await pumpPage(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'Inexistente');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum pedido encontrado nesta seção.'), findsOneWidget);
    expect(find.text('Cadastrar pedido'), findsNothing);
  });

  testWidgets('limpa a pesquisa pelo botão de fechar', (tester) async {
    final repository = FakeOrderRepository(orders: [sampleOrder()]);
    await pumpPage(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump();
    await tester.tap(find.byTooltip('Limpar pesquisa'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Limpar pesquisa'), findsNothing);
    expect(find.text('ANA PAULA'), findsOneWidget);
  });

  testWidgets('exibe contadores das seções e abre Em andamento por padrão',
      (tester) async {
    final repository = FakeOrderRepository(
      orders: [
        sampleOrder(id: 1, customerName: 'Ana'),
        sampleOrder(id: 2, customerName: 'Bruno'),
        sampleOrder(
          id: 3,
          customerName: 'Carla',
          productionBatchId: 7,
        ),
      ],
    );

    await pumpPage(tester, repository: repository);

    expect(find.text('Em andamento (2)'), findsOneWidget);
    expect(find.text('Produção (1)'), findsOneWidget);
    expect(find.text('ANA'), findsOneWidget);
    expect(find.text('BRUNO'), findsOneWidget);
    expect(find.text('CARLA'), findsNothing);
  });

  testWidgets('aba Produção mostra apenas pedidos em lote e identifica o lote',
      (tester) async {
    final repository = FakeOrderRepository(
      orders: [
        sampleOrder(id: 1, customerName: 'Ana'),
        sampleOrder(
          id: 2,
          customerName: 'Bruno',
          productionBatchId: 12,
        ),
      ],
    );

    await pumpPage(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();

    expect(find.text('BRUNO'), findsOneWidget);
    expect(find.text('Lote #0012'), findsOneWidget);
    expect(find.text('ANA'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets('volta para Em andamento mantendo a separação dos pedidos',
      (tester) async {
    final repository = FakeOrderRepository(
      orders: [
        sampleOrder(id: 1, customerName: 'Ana'),
        sampleOrder(
          id: 2,
          customerName: 'Bruno',
          productionBatchId: 3,
        ),
      ],
    );

    await pumpPage(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('orders-section-ongoing')));
    await tester.pumpAndSettle();

    expect(find.text('ANA'), findsOneWidget);
    expect(find.text('BRUNO'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets('exibe estado vazio específico na aba Produção', (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(orders: [sampleOrder()]),
    );

    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum pedido enviado para produção.'), findsOneWidget);
    expect(find.text('Cadastrar pedido'), findsNothing);
  });

  testWidgets('busca filtra somente os pedidos da seção ativa', (tester) async {
    final repository = FakeOrderRepository(
      orders: [
        sampleOrder(id: 1, customerName: 'Ana Produção'),
        sampleOrder(
          id: 2,
          customerName: 'Ana Fábrica',
          productionBatchId: 4,
        ),
        sampleOrder(
          id: 3,
          customerName: 'Bruno Fábrica',
          productionBatchId: 5,
        ),
      ],
    );

    await pumpPage(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('ANA FÁBRICA'), findsOneWidget);
    expect(find.text('ANA PRODUÇÃO'), findsNothing);
    expect(find.text('BRUNO FÁBRICA'), findsNothing);
    expect(find.text('Em andamento (1)'), findsOneWidget);
    expect(find.text('Produção (2)'), findsOneWidget);
  });

  testWidgets('busca sem resultado usa mensagem da seção ativa',
      (tester) async {
    final repository = FakeOrderRepository(
      orders: [sampleOrder(productionBatchId: 8)],
    );

    await pumpPage(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('orders-section-production')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Inexistente');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum pedido encontrado nesta seção.'),
      findsOneWidget,
    );
    expect(find.text('Cadastrar pedido'), findsNothing);
  });

  testWidgets('abre formulário de novo lançamento pelo botão', (tester) async {
    await pumpPage(
      tester,
      repository: FakeOrderRepository(),
      formPageBuilder: (_) => const Scaffold(
        body: Center(child: Text('Formulário fake')),
      ),
    );

    await tester.tap(find.text('Novo pedido'));
    await tester.pumpAndSettle();

    expect(find.text('Formulário fake'), findsOneWidget);
  });

  testWidgets('abre pedido para edição ao tocar no card', (tester) async {
    Order? openedOrder;
    final order = sampleOrder(id: 8);
    await pumpPage(
      tester,
      repository: FakeOrderRepository(orders: [order]),
      formPageBuilder: (value) {
        openedOrder = value;
        return const Scaffold(body: Text('Edição fake'));
      },
    );

    await tester.tap(find.text('Pedido #0008'));
    await tester.pumpAndSettle();

    expect(openedOrder?.id, 8);
    expect(find.text('Edição fake'), findsOneWidget);
  });

  testWidgets('cancela exclusão sem remover o pedido', (tester) async {
    final repository = FakeOrderRepository(orders: [sampleOrder()]);
    await pumpPage(tester, repository: repository);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.deletedId, isNull);
    expect(find.text('Pedido #0001'), findsOneWidget);
  });

  testWidgets('exclui lançamento após confirmação', (tester) async {
    final repository = FakeOrderRepository(orders: [sampleOrder()]);
    await pumpPage(tester, repository: repository);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir pedido?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(repository.deletedId, 1);
    expect(find.text('Nenhum pedido em andamento.'), findsOneWidget);
  });

  group('imagens nos detalhes do pedido', () {
    late Directory imageDirectory;

    setUp(() {
      imageDirectory =
          Directory.systemTemp.createTempSync('myshoes_order_images_');
    });

    tearDown(() {
      if (imageDirectory.existsSync()) {
        imageDirectory.deleteSync(recursive: true);
      }
    });

    Product productWithImage({required String thumbnailPath}) => Product(
          id: 1,
          brand: 'Nike',
          model: 'Air Max',
          minimumSize: 34,
          maximumSize: 44,
          costPrice: 150,
          images: [
            ProductImage(
              id: 10,
              productId: 1,
              imagePath: thumbnailPath,
              thumbnailPath: thumbnailPath,
              position: 0,
              isPrimary: true,
              createdAt: DateTime(2026, 7, 27),
            ),
          ],
        );

    File createImage(String name) {
      final file = File('${imageDirectory.path}/$name.png');
      file.writeAsBytesSync(const <int>[
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
        0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
        0, 0, 0, 13, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 240,
        31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69,
        78, 68, 174, 66, 96, 130,
      ]);
      return file;
    }

    testWidgets('mostra miniatura principal e abre a galeria', (tester) async {
      final image = createImage('principal');
      final product = productWithImage(thumbnailPath: image.path);

      await pumpPage(
        tester,
        repository: FakeOrderRepository(orders: [sampleOrder()]),
        productRepository: FakeProductRepository(productsById: {1: product}),
      );

      expect(
        find.byKey(const ValueKey('product-thumbnail-file')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('order-item-thumbnail-1')));
      await tester.pumpAndSettle();

      expect(find.byType(ProductImageGalleryPage), findsOneWidget);
      expect(find.text('1 de 1'), findsOneWidget);
    });

    testWidgets('mostra ícone quando o tênis não possui foto', (tester) async {
      const product = Product(
        id: 1,
        brand: 'Nike',
        model: 'Air Max',
        minimumSize: 34,
        maximumSize: 44,
        costPrice: 150,
      );

      await pumpPage(
        tester,
        repository: FakeOrderRepository(orders: [sampleOrder()]),
        productRepository:
            FakeProductRepository(productsById: const {1: product}),
      );

      expect(
        find.byKey(const ValueKey('product-thumbnail-fallback')),
        findsOneWidget,
      );
      expect(find.byType(ProductImageGalleryPage), findsNothing);
    });

    testWidgets('usa fallback quando o arquivo da miniatura está ausente',
        (tester) async {
      final missingPath = '${imageDirectory.path}/ausente.png';
      final product = productWithImage(thumbnailPath: missingPath);

      await pumpPage(
        tester,
        repository: FakeOrderRepository(orders: [sampleOrder()]),
        productRepository: FakeProductRepository(productsById: {1: product}),
      );

      expect(
        find.byKey(const ValueKey('product-thumbnail-fallback')),
        findsOneWidget,
      );
    });
  });

}
