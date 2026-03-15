import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/cart_item_model.dart';
import '../services/cart_service.dart';
import '../utils/cart_extensions.dart';

class CartProvider extends ChangeNotifier {
  CartProvider._() {
    _service.addListener(_relay);
  }

  static final CartProvider instance = CartProvider._();

  final CartService _service = CartService.instance;

  List<CartItemModel> get items => _service.unifiedItems;

  List<CartItemModel> get merchItems => items.byType(CartItemType.merch);

  List<CartItemModel> get mediaItems => items.byType(CartItemType.media);

  bool get loading => _service.loading;

  Object? get error => _service.error;

  bool get isEmpty => items.isEmpty;

  int get totalItemsCount => items.totalLines();

  int get totalQuantity => items.totalQuantity();

  double get merchSubtotal => merchItems.grandTotal();

  double get mediaSubtotal => mediaItems.grandTotal();

  double get grandTotal => items.grandTotal();

  List<CartItemModel> get checkoutEligibleItems =>
      items.where((item) => item.safeQuantity > 0).toList(growable: false);

  List<CartItemModel> get merchCheckoutItems =>
      checkoutEligibleItems.byType(CartItemType.merch);

  List<CartItemModel> get mediaCheckoutItems =>
      checkoutEligibleItems.byType(CartItemType.media);

  void start() {
    _service.start();
  }

  Future<void> init(String uid) async {
    start();
    await _service.init(uid);
  }

  Future<void> addCartItem(CartItemModel item) async {
    await _service.addCartItem(item);
  }

  Future<void> removeCartItem(String cartItemId) async {
    await _service.removeCartItem(cartItemId);
  }

  Future<void> updateItemQuantity(String cartItemId, int quantity) async {
    await _service.updateCartItemQuantity(cartItemId, quantity);
  }

  Future<void> incrementItem(String cartItemId) async {
    await _service.incrementCartItem(cartItemId);
  }

  Future<void> decrementItem(String cartItemId) async {
    await _service.decrementCartItem(cartItemId);
  }

  Future<void> clearCart() async {
    await _service.clearCart();
  }

  Future<void> clearMerch() async {
    await _service.clearItemsByType(CartItemType.merch);
  }

  Future<void> clearMedia() async {
    await _service.clearItemsByType(CartItemType.media);
  }

  Future<void> migrateLegacyCartsToUnifiedCart(String uid) {
    return _service.migrateLegacyCartsToUnifiedCart(uid);
  }

  Map<String, dynamic> buildCheckoutPayload() {
    return <String, dynamic>{
      'currency': items.isEmpty ? 'EUR' : items.first.currency,
      'summary': <String, dynamic>{
        'totalItemsCount': totalItemsCount,
        'totalQuantity': totalQuantity,
        'merchSubtotal': merchSubtotal,
        'mediaSubtotal': mediaSubtotal,
        'grandTotal': grandTotal,
      },
      'groups': buildCheckoutGroupsByType(),
    };
  }

  Map<String, List<Map<String, dynamic>>> buildCheckoutGroupsByType() {
    return <String, List<Map<String, dynamic>>>{
      'merch': merchCheckoutItems.map((item) => item.toMap()).toList(growable: false),
      'media': mediaCheckoutItems.map((item) => item.toMap()).toList(growable: false),
    };
  }

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  void disposeListeners() {}

  void _relay() {
    notifyListeners();
  }
}