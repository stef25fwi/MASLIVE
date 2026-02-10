import 'package:flutter_test/flutter_test.dart';
import 'package:maslive/services/cart_service.dart';
import 'package:maslive/models/product_model.dart';

void main() {
  group('CartService', () {
    late CartService cartService;

    setUp(() {
      cartService = CartService.instance;
      cartService.clear();
    });

    test('addProduct adds item to cart', () {
      final product = GroupProduct(
        id: 'test-1',
        title: 'Test Product',
        priceCents: 1000,
        imageUrl: '',
        category: 'Test',
        isActive: true,
        moderationStatus: 'approved',
        stockByVariant: {'M|Noir': 10},
        availableSizes: ['M'],
        availableColors: ['Noir'],
      );

      cartService.addProduct(
        groupId: 'test-group',
        product: product,
        size: 'M',
        color: 'Noir',
        quantity: 2,
      );

      expect(cartService.items.length, 1);
      expect(cartService.items.first.quantity, 2);
      expect(cartService.totalCents, 2000);
    });

    test('addProduct increments quantity for existing item', () {
      final product = GroupProduct(
        id: 'test-1',
        title: 'Test Product',
        priceCents: 1000,
        imageUrl: '',
        category: 'Test',
        isActive: true,
        moderationStatus: 'approved',
        stockByVariant: {'M|Noir': 10},
        availableSizes: ['M'],
        availableColors: ['Noir'],
      );

      cartService.addProduct(
        groupId: 'test-group',
        product: product,
        size: 'M',
        color: 'Noir',
        quantity: 1,
      );

      cartService.addProduct(
        groupId: 'test-group',
        product: product,
        size: 'M',
        color: 'Noir',
        quantity: 2,
      );

      expect(cartService.items.length, 1);
      expect(cartService.items.first.quantity, 3);
      expect(cartService.totalCents, 3000);
    });

    test('removeKey removes item from cart', () {
      final product = GroupProduct(
        id: 'test-1',
        title: 'Test Product',
        priceCents: 1000,
        imageUrl: '',
        category: 'Test',
        isActive: true,
        moderationStatus: 'approved',
        stockByVariant: {'M|Noir': 10},
        availableSizes: ['M'],
        availableColors: ['Noir'],
      );

      cartService.addProduct(
        groupId: 'test-group',
        product: product,
        size: 'M',
        color: 'Noir',
        quantity: 1,
      );

      final key = cartService.items.first.key;
      cartService.removeKey(key);

      expect(cartService.items.length, 0);
      expect(cartService.totalCents, 0);
    });

    test('setQuantity updates item quantity', () {
      final product = GroupProduct(
        id: 'test-1',
        title: 'Test Product',
        priceCents: 1000,
        imageUrl: '',
        category: 'Test',
        isActive: true,
        moderationStatus: 'approved',
        stockByVariant: {'M|Noir': 10},
        availableSizes: ['M'],
        availableColors: ['Noir'],
      );

      cartService.addProduct(
        groupId: 'test-group',
        product: product,
        size: 'M',
        color: 'Noir',
        quantity: 2,
      );

      final key = cartService.items.first.key;
      cartService.setQuantity(key, 5);

      expect(cartService.items.first.quantity, 5);
      expect(cartService.totalCents, 5000);
    });

    test('setQuantity removes item when quantity is 0', () {
      final product = GroupProduct(
        id: 'test-1',
        title: 'Test Product',
        priceCents: 1000,
        imageUrl: '',
        category: 'Test',
        isActive: true,
        moderationStatus: 'approved',
        stockByVariant: {'M|Noir': 10},
        availableSizes: ['M'],
        availableColors: ['Noir'],
      );

      cartService.addProduct(
        groupId: 'test-group',
        product: product,
        size: 'M',
        color: 'Noir',
        quantity: 2,
      );

      final key = cartService.items.first.key;
      cartService.setQuantity(key, 0);

      expect(cartService.items.length, 0);
    });

    test('clear removes all items', () {
      final product = GroupProduct(
        id: 'test-1',
        title: 'Test Product',
        priceCents: 1000,
        imageUrl: '',
        category: 'Test',
        isActive: true,
        moderationStatus: 'approved',
        stockByVariant: {'M|Noir': 10},
        availableSizes: ['M'],
        availableColors: ['Noir'],
      );

      cartService.addProduct(
        groupId: 'test-group',
        product: product,
        size: 'M',
        color: 'Noir',
        quantity: 2,
      );

      cartService.clear();

      expect(cartService.items.length, 0);
      expect(cartService.totalCents, 0);
    });

    test('totalLabel formats price correctly', () {
      final product = GroupProduct(
        id: 'test-1',
        title: 'Test Product',
        priceCents: 1250,
        imageUrl: '',
        category: 'Test',
        isActive: true,
        moderationStatus: 'approved',
        stockByVariant: {'M|Noir': 10},
        availableSizes: ['M'],
        availableColors: ['Noir'],
      );

      cartService.addProduct(
        groupId: 'test-group',
        product: product,
        size: 'M',
        color: 'Noir',
        quantity: 2,
      );

      expect(cartService.totalLabel, '€25');
    });
  });
}
