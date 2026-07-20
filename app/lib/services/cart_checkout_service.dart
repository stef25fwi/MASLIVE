import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../features/media_marketplace/presentation/widgets/media_delivery_option_dialog.dart';
import '../pages/checkout/storex_checkout_stripe.dart';
import '../providers/cart_provider.dart';
import '../ui/snack/top_snack_bar.dart';
import 'checkout/checkout_gateway.dart';

class CartCheckoutService {
  const CartCheckoutService._();

  static String _webRouteUrl(String route) => CheckoutGateway.webRouteUrl(route);

  static Future<void> _openStripeCheckoutUrl(String rawUrl) =>
      CheckoutGateway.openCheckoutUrl(rawUrl);

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
    final normalized = promoCode.trim().toUpperCase();

    // Le serveur vérifie lui-même que le panier est composé uniquement de
    // photos/packs, que le photographe et la galerie correspondent au code,
    // puis mémorise la validation pendant dix minutes pour le checkout.
    try {
      final photographerResult = await validatePhotographerPromoCode(normalized);
      if (photographerResult['valid'] == true) return photographerResult;
    } on FirebaseFunctionsException {
      // Ce n'est pas un panier média compatible : on essaie ensuite les codes
      // généraux MASLIVE/StoreX, validés par leur propre fonction sécurisée.
    }

    final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
        .httpsCallable('validatePromoCode');
    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'promoCode': normalized,
      'subtotalCents': subtotalCents,
    });
    return Map<String, dynamic>.from(response.data);
  }

  static Future<Map<String, dynamic>> validatePhotographerPromoCode(
    String promoCode,
  ) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
        .httpsCallable('validatePhotographerPromoCode');
    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'promoCode': promoCode.trim().toUpperCase(),
    });
    return Map<String, dynamic>.from(response.data);
  }

  static Future<void> startMerchCheckout(BuildContext context) async {
    StorexCheckoutFlow.start(context);
  }

  static Future<bool?> _resolveMediaHdUpgrade(
    BuildContext context,
    bool? explicitChoice,
  ) async {
    if (explicitChoice != null) return explicitChoice;
    if (!context.mounted) return null;
    return showMediaDeliveryOptionDialog(context);
  }

  static Map<String, dynamic> _checkoutPayloadWithDelivery(
    CartProvider cart, {
    required bool hdUpgrade,
  }) {
    return <String, dynamic>{
      ...cart.buildCheckoutPayload(),
      'mediaDeliveryOptions': <String, dynamic>{
        'hdUpgrade': hdUpgrade,
      },
    };
  }

  static Future<void> startMediaCheckout(
    BuildContext context,
    CartProvider cart, {
    bool? hdUpgrade,
    String? promoCode,
  }) async {
    final selectedHdUpgrade = await _resolveMediaHdUpgrade(context, hdUpgrade);
    if (selectedHdUpgrade == null || !context.mounted) return;

    final normalizedPromo = promoCode?.trim().toUpperCase() ?? '';
    final callable = FirebaseFunctions.instanceFor(region: 'us-east1').httpsCallable(
      normalizedPromo.isEmpty
          ? 'createMediaMarketplaceCheckout'
          : 'createMediaMarketplacePromoCheckout',
    );
    final checkoutPayload = _checkoutPayloadWithDelivery(
      cart,
      hdUpgrade: selectedHdUpgrade,
    );

    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'checkoutPayload': checkoutPayload,
      'promoCode': normalizedPromo,
      'mediaDeliveryOptions': <String, dynamic>{
        'hdUpgrade': selectedHdUpgrade,
      },
      'successUrl': _webRouteUrl('/media-marketplace/success'),
      'cancelUrl': _webRouteUrl('/cart'),
    });

    final data = Map<String, dynamic>.from(response.data);
    try {
      final rawUrl = (data['checkoutUrl'] ?? '').toString().trim();
      await _openStripeCheckoutUrl(rawUrl);
    } catch (error) {
      await releaseMediaCheckoutLock();
      rethrow;
    }

    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      SnackBar(
        content: Text(
          normalizedPromo.isNotEmpty
              ? 'Checkout média ouvert avec le code $normalizedPromo'
              : selectedHdUpgrade
                  ? 'Checkout média HD ouvert dans Stripe (+${mediaHdUpgradePrice.toStringAsFixed(2)} €)'
                  : 'Checkout média ouvert avec la version Web incluse',
        ),
      ),
    );
  }

  static Future<void> startMixedCheckout(
    BuildContext context,
    CartProvider cart, {
    required int shippingCents,
    required String shippingMethod,
    String? promoCode,
    bool? mediaHdUpgrade,
  }) async {
    final selectedHdUpgrade = await _resolveMediaHdUpgrade(
      context,
      mediaHdUpgrade,
    );
    if (selectedHdUpgrade == null || !context.mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté');
    }

    final shippingAddress = await _loadSavedShippingAddress(user.uid);
    final checkoutPayload = _checkoutPayloadWithDelivery(
      cart,
      hdUpgrade: selectedHdUpgrade,
    );

    if (kIsWeb) {
      final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable('createMixedCartCheckoutSession');

      final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'currency': 'eur',
        'shippingCents': shippingCents,
        'shippingMethod': shippingMethod,
        'address': shippingAddress,
        'promoCode': promoCode ?? '',
        'checkoutPayload': checkoutPayload,
        'mediaDeliveryOptions': <String, dynamic>{
          'hdUpgrade': selectedHdUpgrade,
        },
        'successUrl': _webRouteUrl('/storex/paymentComplete'),
        'cancelUrl': _webRouteUrl('/cart'),
        'continueToRoute': '/cart',
      });

      final data = Map<String, dynamic>.from(response.data);
      final rawUrl = (data['checkoutUrl'] ?? '').toString().trim();

      try {
        await _openStripeCheckoutUrl(rawUrl);
      } catch (error) {
        await releaseMediaCheckoutLock(uid: user.uid);
        rethrow;
      }
      return;
    }

    final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
        .httpsCallable('createMixedCartPaymentIntent');

    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'currency': 'eur',
      'shippingCents': shippingCents,
      'shippingMethod': shippingMethod,
      'address': shippingAddress,
      'promoCode': promoCode ?? '',
      'checkoutPayload': checkoutPayload,
      'mediaDeliveryOptions': <String, dynamic>{
        'hdUpgrade': selectedHdUpgrade,
      },
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
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'FR'),
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'FR',
            currencyCode: 'EUR',
            testEnv: kDebugMode,
          ),
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

    try {
      final confirm = FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable('confirmStorexPayment');
      await confirm.call<Map<String, dynamic>>({'orderId': storeOrderId});
    } catch (_) {
      // Filet de sécurité: le webhook Stripe finalisera la commande.
    }

    await cart.clearCart();

    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      SnackBar(
        content: Text(
          selectedHdUpgrade
              ? 'Paiement confirmé (merch + média HD)'
              : 'Paiement confirmé (merch + média Web)',
        ),
      ),
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
