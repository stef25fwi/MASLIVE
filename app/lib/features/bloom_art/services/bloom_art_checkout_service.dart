import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../ui/snack/top_snack_bar.dart';

class BloomArtCheckoutService {
  BloomArtCheckoutService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFunctions _functions;

  String _absoluteWebRoute(String route) {
    final normalizedRoute = route.startsWith('/') ? route : '/$route';
    if (kIsWeb) {
      return '${Uri.base.origin}/#$normalizedRoute';
    }
    // TODO: remplacer par un deep-link/app-link natif si votre app mobile
    // gere deja les retours Stripe vers l'application.
    return 'https://maslive.web.app/#$normalizedRoute';
  }

  Future<void> startCheckout(
    BuildContext context, {
    required String offerId,
    required String itemId,
  }) async {
    final callable = _functions.httpsCallable('createBloomArtCheckout');
    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'offerId': offerId,
      'successUrl': _absoluteWebRoute('/bloom-art/dashboard'),
      'cancelUrl': _absoluteWebRoute('/bloom-art/item/$itemId'),
    });
    final data = Map<String, dynamic>.from(response.data);
    final rawUrl = (data['checkoutUrl'] ?? '').toString().trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || rawUrl.isEmpty) {
      throw StateError('checkoutUrl Stripe manquante pour Bloom Art');
    }

    final launched = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!launched) {
      throw StateError('Impossible d\'ouvrir Stripe Checkout');
    }

    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      const SnackBar(content: Text('Checkout Bloom Art ouvert dans Stripe')),
    );
  }
}