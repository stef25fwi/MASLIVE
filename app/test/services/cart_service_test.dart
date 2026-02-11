import 'package:flutter_test/flutter_test.dart';

import 'package:masslive/services/cart_service.dart';

void main() {
  setUp(() {
    CartService.instance.clear();
  });

  test('addItemFromFields fusionne les quantités et conserve imagePath', () {
    CartService.instance.addItemFromFields(
      groupId: 'MASLIVE',
      productId: 'p1',
      title: 'Produit 1',
      priceCents: 1234,
      imageUrl: '',
      imagePath: 'assets/images/p1.png',
      size: 'M',
      color: 'Noir',
      quantity: 1,
    );

    expect(CartService.instance.items, hasLength(1));
    expect(CartService.instance.items.first.quantity, 1);
    expect(CartService.instance.items.first.imagePath, 'assets/images/p1.png');

    CartService.instance.addItemFromFields(
      groupId: 'MASLIVE',
      productId: 'p1',
      title: 'Produit 1',
      priceCents: 1234,
      imageUrl: '',
      imagePath: 'assets/images/p1.png',
      size: 'M',
      color: 'Noir',
      quantity: 2,
    );

    expect(CartService.instance.items, hasLength(1));
    expect(CartService.instance.items.first.quantity, 3);
  });
}
