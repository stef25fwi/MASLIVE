import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/commerce/data/commerce_repository.dart';
import 'package:masslive/features/commerce/domain/commerce_models.dart';
import 'package:masslive/features/commerce/presentation/controllers/product_controller.dart';
import 'package:masslive/features/commerce/presentation/pages/boutique_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('displays products and increments cart quantity', (
    tester,
  ) async {
    final env = await _buildEnv(
      products: [
        _product(name: 'T-shirt MASLIVE', price: 29.0),
      ],
    );
    addTearDown(env.controller.dispose);

    await tester.pumpWidget(_buildApp(env.controller));
    await tester.pumpAndSettle();

    expect(find.text('T-shirt MASLIVE'), findsOneWidget);
    expect(find.text('29.00 EUR'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('x1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('x2'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows empty cart placeholder', (tester) async {
    final env = await _buildEnv();
    addTearDown(env.controller.dispose);

    await tester.pumpWidget(_buildApp(env.controller));
    await tester.pumpAndSettle();

    await _openCart(tester);

    expect(find.text('Panier'), findsOneWidget);
    expect(find.text('Ton panier est vide.'), findsOneWidget);
    expect(find.text('Commander'), findsOneWidget);
  });

  testWidgets('creates an order and decrements stock on checkout', (
    tester,
  ) async {
    final env = await _buildEnv(
      products: [
        _product(name: 'Sweat MASLIVE', price: 59.0, stockQty: 3),
      ],
    );
    addTearDown(env.controller.dispose);

    await tester.pumpWidget(_buildApp(env.controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
    await tester.pumpAndSettle();

    await _openCart(tester);

    expect(find.text('Total: 59.00 EUR'), findsOneWidget);

    await tester.tap(find.text('Commander'));
    await tester.pumpAndSettle();

    final orders = await env.firestore
        .collection('shops')
        .doc('shop-1')
        .collection('orders')
        .get();
    expect(orders.docs, hasLength(1));

    final orderData = orders.docs.single.data();
    expect(orderData['status'], 'created');
    expect(orderData['userId'], 'user-1');
    expect(orderData['total'], 59.0);

    final products = await env.firestore
        .collection('shops')
        .doc('shop-1')
        .collection('products')
        .get();
    expect(products.docs.single.data()['stockQty'], 2);

    expect(find.textContaining('Commande créée:'), findsOneWidget);

    await _openCart(tester);

    expect(find.text('Ton panier est vide.'), findsOneWidget);
  });

  testWidgets('shows out-of-stock products without cart action', (
    tester,
  ) async {
    final env = await _buildEnv(
      products: [
        _product(name: 'Poster collector', price: 12.0, stockQty: 0),
      ],
    );
    addTearDown(env.controller.dispose);

    await tester.pumpWidget(_buildApp(env.controller));
    await tester.pumpAndSettle();

    expect(find.text('Poster collector'), findsOneWidget);
    expect(find.text('Rupture'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.byIcon(Icons.add_shopping_cart_outlined), findsNothing);
  });
}

Widget _buildApp(ProductController controller) {
  return MaterialApp(
    home: BoutiquePage(
      shopId: controller.shopId,
      userId: 'user-1',
      controller: controller,
    ),
  );
}

Future<void> _openCart(WidgetTester tester) async {
  final buttonFinder = find.widgetWithIcon(
    IconButton,
    Icons.shopping_bag_outlined,
  );
  expect(buttonFinder, findsOneWidget);

  final button = tester.widget<IconButton>(buttonFinder);
  button.onPressed?.call();
  await tester.pumpAndSettle();
}

Future<_TestEnv> _buildEnv({
  List<Product> products = const [],
}) async {
  final firestore = FakeFirebaseFirestore();
  final repository = CommerceRepository(db: firestore);

  for (final product in products) {
    await repository.createProduct('shop-1', product);
  }

  return _TestEnv(
    firestore: firestore,
    repository: repository,
    controller: ProductController(
      shopId: 'shop-1',
      commerceRepo: repository,
    ),
  );
}

class _TestEnv {
  final FakeFirebaseFirestore firestore;
  final CommerceRepository repository;
  final ProductController controller;

  const _TestEnv({
    required this.firestore,
    required this.repository,
    required this.controller,
  });
}

Product _product({
  required String name,
  required double price,
  bool isActive = true,
  int stockQty = 8,
  int stockAlertQty = 2,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: '',
    name: name,
    description: 'Produit de test',
    price: price,
    currency: 'EUR',
    categoryId: null,
    tags: const ['test'],
    isActive: isActive,
    isFeatured: false,
    stockQty: stockQty,
    stockAlertQty: stockAlertQty,
    sku: null,
    barcode: null,
    country: null,
    event: null,
    circuit: null,
    placeGeo: null,
    mainImageUrl: null,
    imageCount: 0,
    images: const [],
    searchTokens: const [],
    createdAt: now,
    updatedAt: now,
    stockStatus: CommerceRepository.computeStockStatus(stockQty, stockAlertQty),
  );
}
