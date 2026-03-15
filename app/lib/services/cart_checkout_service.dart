import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/checkout/storex_checkout_stripe.dart';
import '../providers/cart_provider.dart';
import '../ui/snack/top_snack_bar.dart';

class CartCheckoutService {
  const CartCheckoutService._();

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

    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      const SnackBar(content: Text('Checkout media ouvert dans Stripe')),
    );
  }
}
