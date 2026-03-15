import '../models/cart_item_model.dart';

extension CartItemIterableX on Iterable<CartItemModel> {
  List<CartItemModel> byType(CartItemType type) {
    return where((item) => item.itemType == type).toList(growable: false);
  }

  double subtotalFor(CartItemType type) {
    return where((item) => item.itemType == type)
        .fold<double>(0, (total, item) => total + item.totalPrice);
  }

  double grandTotal() {
    return fold<double>(0, (total, item) => total + item.totalPrice);
  }

  int totalLines() {
    return length;
  }

  int totalQuantity() {
    return fold<int>(0, (total, item) => total + item.safeQuantity);
  }

  Map<CartItemType, List<CartItemModel>> groupedByType() {
    return <CartItemType, List<CartItemModel>>{
      CartItemType.merch: byType(CartItemType.merch),
      CartItemType.media: byType(CartItemType.media),
    };
  }
}

extension CartPriceFormattingX on num {
  String formatEuro() {
    return '${toStringAsFixed(2)} EUR';
  }
}