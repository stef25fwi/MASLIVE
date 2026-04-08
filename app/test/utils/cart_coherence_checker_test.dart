import 'package:flutter_test/flutter_test.dart';

import 'package:masslive/models/cart_item_model.dart';
import 'package:masslive/services/cart_service.dart';
import 'package:masslive/utils/cart_coherence_checker.dart';

void main() {
  setUp(() {
    CartService.instance.clear();
  });

  group('CartCoherenceChecker', () {
    test('detects empty cart as coherent', () {
      final issues = CartCoherenceChecker.verify();
      expect(issues, isEmpty);
    });

    test('detects missing required fields', () {
      final item = CartItemModel(
        id: 'ci_test',
        itemType: CartItemType.merch,
        productId: '', // Missing required field
        sellerId: '',
        eventId: '',
        title: 'Test',
        imageUrl: 'test.png',
        unitPrice: 10,
        quantity: 1,
        currency: 'EUR',
        isDigital: false,
        requiresShipping: true,
      );

      CartService.instance.addCartItem(item);
      final issues = CartCoherenceChecker.verify();

      expect(
        issues.any((i) => i.message.contains('productId')),
        true,
        reason: 'Should detect missing productId',
      );
    });

    test('detects invalid quantity values', () {
      final item = CartItemModel(
        id: 'ci_test',
        itemType: CartItemType.merch,
        productId: 'p1',
        sellerId: '',
        eventId: '',
        title: 'Test',
        imageUrl: 'test.png',
        unitPrice: 10,
        quantity: 1500, // Invalid: > 999
        currency: 'EUR',
        isDigital: false,
        requiresShipping: true,
      );

      CartService.instance.addCartItem(item);
      final issues = CartCoherenceChecker.verify();

      expect(
        issues.any((i) => i.message.contains('invalid quantity')),
        true,
        reason: 'Should detect quantity > 999',
      );
    });

    test('detects negative prices', () {
      final item = CartItemModel(
        id: 'ci_test',
        itemType: CartItemType.merch,
        productId: 'p1',
        sellerId: '',
        eventId: '',
        title: 'Test',
        imageUrl: 'test.png',
        unitPrice: -10, // Invalid: negative
        quantity: 1,
        currency: 'EUR',
        isDigital: false,
        requiresShipping: true,
      );

      CartService.instance.addCartItem(item);
      final issues = CartCoherenceChecker.verify();

      expect(
        issues.any((i) => i.message.contains('negative price')),
        true,
        reason: 'Should detect negative price',
      );
    });

    test('detects media items with invalid flags', () {
      final item = CartItemModel(
        id: 'ci_test',
        itemType: CartItemType.media,
        productId: 'p1',
        sellerId: 'seller1',
        eventId: 'event1',
        title: 'Photo',
        imageUrl: 'photo.jpg',
        unitPrice: 50,
        quantity: 1,
        currency: 'EUR',
        isDigital: false, // Should be true for media
        requiresShipping: true, // Should be false for media
      );

      CartService.instance.addCartItem(item);
      final issues = CartCoherenceChecker.verify();

      expect(
        issues.where((i) => i.severity == CoherenceSeverity.critical),
        isNotEmpty,
        reason:
            'Should detect critical issue: media with requiresShipping=true',
      );
    });

    test('detects multiple currencies', () {
      final item1 = CartItemModel(
        id: 'ci_test1',
        itemType: CartItemType.merch,
        productId: 'p1',
        sellerId: '',
        eventId: '',
        title: 'Test1',
        imageUrl: 'test.png',
        unitPrice: 10,
        quantity: 1,
        currency: 'EUR',
        isDigital: false,
        requiresShipping: true,
      );

      final item2 = CartItemModel(
        id: 'ci_test2',
        itemType: CartItemType.merch,
        productId: 'p2',
        sellerId: '',
        eventId: '',
        title: 'Test2',
        imageUrl: 'test.png',
        unitPrice: 10,
        quantity: 1,
        currency: 'USD', // Different currency
        isDigital: false,
        requiresShipping: true,
      );

      CartService.instance.addCartItem(item1);
      CartService.instance.addCartItem(item2);
      final issues = CartCoherenceChecker.verify();

      expect(
        issues.any((i) => i.message.contains('multiple currencies')),
        true,
        reason: 'Should detect multiple currency types',
      );
    });
  });

  group('CartRepair', () {
    test('repair fixes quantity out of range', () async {
      final item = CartItemModel(
        id: 'ci_test',
        itemType: CartItemType.merch,
        productId: 'p1',
        sellerId: '',
        eventId: '',
        title: 'Test',
        imageUrl: 'test.png',
        unitPrice: 10,
        quantity: 1500, // Invalid
        currency: 'EUR',
        isDigital: false,
        requiresShipping: true,
      );

      CartService.instance.addCartItem(item);
      final report = await CartCoherenceChecker.repair();

      expect(
        report.fixedCritical > 0,
        true,
        reason: 'Should fix critical issues',
      );
      expect(report.repaidCount > 0, true, reason: 'Should have made repairs');
    });

    test('repair fixes negative prices', () async {
      final item = CartItemModel(
        id: 'ci_test',
        itemType: CartItemType.merch,
        productId: 'p1',
        sellerId: '',
        eventId: '',
        title: 'Test',
        imageUrl: 'test.png',
        unitPrice: -50, // Invalid
        quantity: 1,
        currency: 'EUR',
        isDigital: false,
        requiresShipping: true,
      );

      CartService.instance.addCartItem(item);
      final report = await CartCoherenceChecker.repair();

      expect(
        report.fixedCritical > 0,
        true,
        reason: 'Should fix critical issues',
      );
    });

    test('repair fixes media item flags', () async {
      final item = CartItemModel(
        id: 'ci_test',
        itemType: CartItemType.media,
        productId: 'p1',
        sellerId: 'seller1',
        eventId: 'event1',
        title: 'Photo',
        imageUrl: 'photo.jpg',
        unitPrice: 50,
        quantity: 1,
        currency: 'EUR',
        isDigital: false, // Should be true
        requiresShipping: true, // Should be false
      );

      CartService.instance.addCartItem(item);
      final report = await CartCoherenceChecker.repair();

      expect(
        report.fixedCritical > 0,
        true,
        reason: 'Should fix media item flags',
      );
      expect(report.repaidCount > 0, true, reason: 'Should have made repairs');
    });
  });
}
