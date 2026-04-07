import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/checkout/storex_checkout_stripe.dart';
import '../providers/cart_provider.dart';
import '../ui/snack/top_snack_bar.dart';

class CartCheckoutService {
  const CartCheckoutService._();

  static Future<void> releaseMediaCheckoutLock({String? uid}) async {
    final resolvedUid = (uid ?? FirebaseAuth.instance.currentUser?.uid)?.trim();
    if (resolvedUid == null || resolvedUid.isEmpty) return;

    await FirebaseFirestore.instance.collection('carts').doc(resolvedUid).set(
      <String, dynamic>{
        'uid': resolvedUid,
        'checkoutLockedUntil': null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<Map<String, dynamic>> validatePromoCode(
    String promoCode, {
    required int subtotalCents,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
        .httpsCallable('validatePromoCode');

    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'promoCode': promoCode.trim().toUpperCase(),
      'subtotalCents': subtotalCents,
    });

    return Map<String, dynamic>.from(response.data);
  }

  static Future<void> startMerchCheckout(BuildContext context) async {
    StorexCheckoutFlow.start(context);
  }

  static Future<void> startMediaCheckout(
    BuildContext context,
    CartProvider cart,
  ) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
        .httpsCallable('createMediaMarketplaceCheckout');

    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'checkoutPayload': cart.buildCheckoutPayload(),
    });

    final data = Map<String, dynamic>.from(response.data);
    try {
      final rawUrl = (data['checkoutUrl'] ?? '').toString().trim();
      final checkoutUri = Uri.tryParse(rawUrl);
      if (checkoutUri == null || rawUrl.isEmpty) {
        throw StateError('checkoutUrl media manquante');
      }

      final launched = await launchUrl(
        checkoutUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Impossible d\'ouvrir Stripe');
      }
    } catch (error) {
      await releaseMediaCheckoutLock();
      rethrow;
    }

    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      const SnackBar(content: Text('Checkout media ouvert dans Stripe')),
    );
  }

  static Future<void> startMixedCheckout(
    BuildContext context,
    CartProvider cart, {
    required int shippingCents,
    required String shippingMethod,
    String? promoCode,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté');
    }

    final shippingAddress = await _loadSavedShippingAddress(user.uid);

    final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
        .httpsCallable('createMixedCartPaymentIntent');

    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'currency': 'eur',
      'shippingCents': shippingCents,
      'shippingMethod': shippingMethod,
      'address': shippingAddress,
      'promoCode': promoCode ?? '',
      'checkoutPayload': cart.buildCheckoutPayload(),
    });

    final data = Map<String, dynamic>.from(response.data);
    final clientSecret = (data['clientSecret'] ?? '').toString();
    final storeOrderId = (data['storeOrderId'] ?? '').toString();
    final mediaOrderId = (data['mediaOrderId'] ?? '').toString();

    if (clientSecret.isEmpty || storeOrderId.isEmpty || mediaOrderId.isEmpty) {
      await releaseMediaCheckoutLock(uid: user.uid);
      throw StateError('Réponse Stripe invalide');
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'MASLIVE',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      await releaseMediaCheckoutLock(uid: user.uid);
      final msg = e.error.localizedMessage ?? e.error.message ?? 'Stripe error';
      throw StateError(msg);
    } catch (_) {
      await releaseMediaCheckoutLock(uid: user.uid);
      rethrow;
    }

    await cart.clearCart();

    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      const SnackBar(content: Text('Paiement confirmé (merch + media)')),
    );
  }

  static Future<Map<String, dynamic>> _loadSavedShippingAddress(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shop_profile')
        .doc('shipping')
        .get();

    final data = snap.data();
    if (data == null) {
      throw StateError('Adresse de livraison introuvable');
    }

    final raw = (data['shippingAddress'] is Map)
        ? Map<String, dynamic>.from(data['shippingAddress'] as Map)
        : Map<String, dynamic>.from(data);

    return raw;
  }
}
