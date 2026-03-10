import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/cart_item_model.dart';
import '../../data/models/cart_model.dart';
import '../../data/repositories/cart_repository.dart';
import '../../domain/services/media_pricing_service.dart';

class MediaCartController extends ChangeNotifier {
  MediaCartController({
    CartRepository? cartRepository,
    MediaPricingService? mediaPricingService,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _cartRepository = cartRepository ?? CartRepository(),
       _mediaPricingService = mediaPricingService ?? const MediaPricingService(),
       _functions = functions ?? FirebaseFunctions.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final CartRepository _cartRepository;
  final MediaPricingService _mediaPricingService;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  bool loading = false;
  bool processingCheckout = false;
  Object? error;
  CartModel? cart;
  String? checkoutUrl;
  String? lastOrderId;

  int get itemCount => cart?.itemCount ?? 0;

  Future<void> loadCurrentUserCart() async {
    final user = _auth.currentUser;
    if (user == null) {
      cart = null;
      error = null;
      notifyListeners();
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      cart = await _cartRepository.getCart(user.uid);
    } catch (err) {
      error = err;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addItem(CartItemModel item) async {
    final user = _auth.currentUser;
    if (user == null) {
      error = StateError('Utilisateur non authentifie');
      notifyListeners();
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      await _cartRepository.addItem(uid: user.uid, item: item);
      cart = await _cartRepository.getCart(user.uid);
    } catch (err) {
      error = err;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> removeItem(String assetId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    loading = true;
    error = null;
    notifyListeners();

    try {
      await _cartRepository.removeItem(uid: user.uid, assetId: assetId);
      cart = await _cartRepository.getCart(user.uid);
    } catch (err) {
      error = err;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    final user = _auth.currentUser;
    if (user == null) return;

    loading = true;
    error = null;
    notifyListeners();

    try {
      await _cartRepository.clearCart(user.uid);
      cart = null;
    } catch (err) {
      error = err;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> get pricingPreview {
    final currentCart = cart;
    final subtotal = currentCart?.subtotal ?? 0;
    return _mediaPricingService
        .computeCheckoutBreakdown(subtotal: subtotal)
        .toMap();
  }

  Future<String?> checkout({
    String? successUrl,
    String? cancelUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      error = StateError('Utilisateur non authentifie');
      notifyListeners();
      return null;
    }

    if (cart == null || cart!.items.isEmpty) {
      error = StateError('Panier vide');
      notifyListeners();
      return null;
    }

    processingCheckout = true;
    error = null;
    checkoutUrl = null;
    lastOrderId = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable('createMediaMarketplaceCheckout');
      final response = await callable.call(<String, dynamic>{
        'successUrl': ?successUrl,
        'cancelUrl': ?cancelUrl,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      checkoutUrl = data['checkoutUrl']?.toString();
      lastOrderId = data['orderId']?.toString();
      return checkoutUrl;
    } catch (err) {
      error = err;
      return null;
    } finally {
      processingCheckout = false;
      notifyListeners();
    }
  }
}