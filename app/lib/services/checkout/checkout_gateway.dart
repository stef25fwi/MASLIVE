import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Passerelle Stripe UNIQUE pour tout le paiement de l'app (boutique, photo,
/// bloom art). Centralise la construction des URLs de retour et l'ouverture de
/// Stripe Checkout, jusque-là dupliquées dans CartCheckoutService et
/// BloomArtCheckoutService.
class CheckoutGateway {
  const CheckoutGateway._();

  /// URL absolue d'une route web (retours success/cancel Stripe).
  /// Sur web: origine courante + hash-route. Sur natif: domaine hébergé.
  static String webRouteUrl(String route) {
    final normalized = route.startsWith('/') ? route : '/$route';
    if (kIsWeb) {
      return '${Uri.base.origin}/#$normalized';
    }
    // TODO(natif): remplacer par un deep-link/app-link si l'app gère les
    // retours Stripe vers l'application.
    return 'https://maslive.web.app/#$normalized';
  }

  /// Ouvre une URL Stripe Checkout. Lève une erreur explicite si l'URL est
  /// vide/invalide ou si le lanceur échoue.
  static Future<void> openCheckoutUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || trimmed.isEmpty) {
      throw StateError('checkoutUrl Stripe manquante');
    }

    final launched = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!launched) {
      throw StateError('Impossible d\'ouvrir Stripe Checkout');
    }
  }
}
