import 'package:flutter/material.dart';

import '../../features/bloom_art/services/bloom_art_checkout_service.dart';
import '../../providers/cart_provider.dart';
import '../cart_checkout_service.dart';

/// Point d'entrée UNIQUE de paiement Stripe pour les 3 domaines produits:
///
/// - **Boutique** (merch) et **Photo** (media): paient via le panier unifié
///   (`CartItemModel`), avec auto-routage selon la composition du panier.
/// - **Bloom Art** (bloomood): paie une offre acceptée (flux offre → paiement),
///   sans panier.
///
/// Les 3 pages appellent CE service (et non plus directement CartCheckoutService
/// ou BloomArtCheckoutService), ce qui donne une seule gestion du paiement.
/// Toutes les URLs Stripe passent par [CheckoutGateway].
///
/// Consolidation backend (étape suivante, à déployer avec tests): faire de
/// `createMixedCartCheckoutSession` la fonction unique en (a) rendant les médias
/// optionnels et (b) acceptant un groupe `bloomArt` dans `buildCheckoutPayload`.
/// La structure client ci-dessous est déjà prête pour ce basculement: seul le
/// corps de ces méthodes changera, pas les appels des pages.
class UnifiedCheckoutService {
  const UnifiedCheckoutService._();

  /// Checkout du panier (boutique + photo). Auto-route:
  /// - merch seul  → flux Storex,
  /// - media seul  → createMediaMarketplaceCheckout,
  /// - mixte       → createMixedCartCheckoutSession.
  static Future<void> startCartCheckout(
    BuildContext context,
    CartProvider cart, {
    int shippingCents = 0,
    String shippingMethod = 'flat_rate',
    String? promoCode,
  }) async {
    final hasMerch = cart.merchCheckoutItems.isNotEmpty;
    final hasMedia = cart.mediaCheckoutItems.isNotEmpty;

    if (!hasMerch && !hasMedia) {
      throw StateError('Panier vide');
    }

    if (hasMerch && hasMedia) {
      return CartCheckoutService.startMixedCheckout(
        context,
        cart,
        shippingCents: shippingCents,
        shippingMethod: shippingMethod,
        promoCode: promoCode,
      );
    }

    if (hasMedia) {
      return CartCheckoutService.startMediaCheckout(context, cart);
    }

    return CartCheckoutService.startMerchCheckout(context);
  }

  /// Checkout Bloom Art (paiement d'une offre acceptée).
  static Future<void> startBloomArtCheckout({
    required String offerId,
    required String itemId,
  }) {
    return BloomArtCheckoutService().startCheckout(
      offerId: offerId,
      itemId: itemId,
    );
  }
}
