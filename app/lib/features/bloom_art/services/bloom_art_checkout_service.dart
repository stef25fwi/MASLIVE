import 'package:cloud_functions/cloud_functions.dart';

import '../../../services/checkout/checkout_gateway.dart';

class BloomArtCheckoutService {
  BloomArtCheckoutService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFunctions _functions;

  Future<void> startCheckout({
    required String offerId,
    required String itemId,
  }) async {
    final callable = _functions.httpsCallable('createBloomArtCheckout');
    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'offerId': offerId,
      // Routes de retour construites par la passerelle Stripe commune.
      'successUrl': CheckoutGateway.webRouteUrl('/bloom-art/dashboard'),
      'cancelUrl': CheckoutGateway.webRouteUrl('/bloom-art/item/$itemId'),
    });
    final data = Map<String, dynamic>.from(response.data);
    final rawUrl = (data['checkoutUrl'] ?? '').toString().trim();
    if (rawUrl.isEmpty) {
      throw StateError('checkoutUrl Stripe manquante pour Bloom Art');
    }
    await CheckoutGateway.openCheckoutUrl(rawUrl);
  }
}