import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_item_model.dart';

class CartValidationError {
  CartValidationError({
    required this.itemId,
    required this.message,
    required this.severity,
  });

  final String itemId;
  final String message;
  final CartValidationSeverity severity;

  @override
  String toString() => '[$severity] $itemId: $message';
}

enum CartValidationSeverity {
  info,
  warning,
  error,
}

class CartValidator {
  const CartValidator._();

  /// Valide un article du panier
  static List<CartValidationError> validateItem(CartItemModel item) {
    final errors = <CartValidationError>[];

    // Validation ID
    if (item.id.trim().isEmpty) {
      errors.add(CartValidationError(
        itemId: '???',
        message: 'ID manquant',
        severity: CartValidationSeverity.error,
      ));
    }

    // Validation titre
    if (item.title.trim().isEmpty) {
      errors.add(CartValidationError(
        itemId: item.id,
        message: 'Titre manquant',
        severity: CartValidationSeverity.error,
      ));
    }

    // Validation productId
    if (item.productId.trim().isEmpty) {
      errors.add(CartValidationError(
        itemId: item.id,
        message: 'ProductId manquant',
        severity: CartValidationSeverity.error,
      ));
    }

    // Validation prix
    if (item.unitPrice < 0) {
      errors.add(CartValidationError(
        itemId: item.id,
        message: 'Prix négatif: ${item.unitPrice}',
        severity: CartValidationSeverity.error,
      ));
    }

    if (item.unitPrice == 0 && item.itemType == CartItemType.merch) {
      errors.add(CartValidationError(
        itemId: item.id,
        message: 'Merch avec prix = 0',
        severity: CartValidationSeverity.warning,
      ));
    }

    // Validation quantité
    if (item.quantity < 1 || item.quantity > 999) {
      errors.add(CartValidationError(
        itemId: item.id,
        message: 'Quantité invalide: ${item.quantity}',
        severity: CartValidationSeverity.error,
      ));
    }

    // Validation devise
    if (item.currency.trim().isEmpty) {
      errors.add(CartValidationError(
        itemId: item.id,
        message: 'Devise manquante',
        severity: CartValidationSeverity.error,
      ));
    }

    // Cohérence merch vs media
    if (item.itemType == CartItemType.merch) {
      if (item.isDigital) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'Merch marqué comme digital',
          severity: CartValidationSeverity.error,
        ));
      }
      if (!item.requiresShipping) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'Merch ne nécessite pas de shipping',
          severity: CartValidationSeverity.warning,
        ));
      }
    }

    if (item.itemType == CartItemType.media) {
      if (!item.isDigital) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'Media n\'est pas digital',
          severity: CartValidationSeverity.error,
        ));
      }
      if (item.requiresShipping) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'Media nécessite du shipping',
          severity: CartValidationSeverity.error,
        ));
      }
      if (item.quantity != 1) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'Media avec quantité != 1',
          severity: CartValidationSeverity.error,
        ));
      }
    }

    // Validation métadonnées
    if (item.itemType == CartItemType.merch && item.metadata != null) {
      final metadata = item.metadata!;
      if (metadata.containsKey('size') && metadata['size'] is! String) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'Size metadata invalide',
          severity: CartValidationSeverity.warning,
        ));
      }
      if (metadata.containsKey('color') && metadata['color'] is! String) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'Color metadata invalide',
          severity: CartValidationSeverity.warning,
        ));
      }
    }

    // Validation dates
    if (item.createdAt != null && item.updatedAt != null) {
      if (item.createdAt!.isAfter(item.updatedAt!)) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'createdAt > updatedAt',
          severity: CartValidationSeverity.warning,
        ));
      }
    }

    return errors;
  }

  /// Valide une liste d'articles (cohérence globale)
  static List<CartValidationError> validateCart(
    List<CartItemModel> items,
  ) {
    final errors = <CartValidationError>[];

    // Valide chaque article individuellement
    for (final item in items) {
      errors.addAll(validateItem(item));
    }

    // Vérifie les doublons d'ID
    final ids = <String>{};
    for (final item in items) {
      if (ids.contains(item.id)) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'ID dupliqué dans le panier',
          severity: CartValidationSeverity.error,
        ));
      }
      ids.add(item.id);
    }

    // Appariements sourceType
    for (final item in items) {
      if (item.itemType == CartItemType.merch &&
          item.sourceType != 'group_shop' &&
          item.sourceType?.isNotEmpty == true) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'sourceType merch invalide: ${item.sourceType}',
          severity: CartValidationSeverity.warning,
        ));
      }
      if (item.itemType == CartItemType.media &&
          item.sourceType != 'media_marketplace' &&
          item.sourceType?.isNotEmpty == true) {
        errors.add(CartValidationError(
          itemId: item.id,
          message: 'sourceType media invalide: ${item.sourceType}',
          severity: CartValidationSeverity.warning,
        ));
      }
    }

    return errors;
  }

  /// Génère un rapport de validation
  static String generateReport(
    List<CartValidationError> errors,
  ) {
    if (errors.isEmpty) return '✅ Panier valide\n';

    final buffer = StringBuffer();
    final errorCount = errors
        .where((e) => e.severity == CartValidationSeverity.error)
        .length;
    final warningCount = errors
        .where((e) => e.severity == CartValidationSeverity.warning)
        .length;
    final infoCount = errors
        .where((e) => e.severity == CartValidationSeverity.info)
        .length;

    buffer.writeln('Rapport de validation du panier:');
    buffer.writeln('  ❌ Erreurs: $errorCount');
    buffer.writeln('  ⚠️  Avertissements: $warningCount');
    buffer.writeln('  ℹ️  Infos: $infoCount');
    buffer.writeln('');

    if (errorCount > 0) {
      buffer.writeln('ERREURS:');
      for (final error in errors
          .where((e) => e.severity == CartValidationSeverity.error)) {
        buffer.writeln('  $error');
      }
      buffer.writeln('');
    }

    if (warningCount > 0) {
      buffer.writeln('AVERTISSEMENTS:');
      for (final warning in errors
          .where((e) => e.severity == CartValidationSeverity.warning)) {
        buffer.writeln('  $warning');
      }
      buffer.writeln('');
    }

    if (infoCount > 0) {
      buffer.writeln('INFOS:');
      for (final info in errors
          .where((e) => e.severity == CartValidationSeverity.info)) {
        buffer.writeln('  $info');
      }
    }

    return buffer.toString();
  }

  /// Vérifie la cohérence depuis Firestore
  static Future<List<CartValidationError>> validateFirestoreCart(
    String uid,
  ) async {
    final errors = <CartValidationError>[];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart_items')
          .get();

      final items = snapshot.docs
          .map(CartItemModel.fromDocument)
          .toList(growable: false);

      errors.addAll(validateCart(items));
    } catch (e) {
      errors.add(CartValidationError(
        itemId: 'FIRESTORE',
        message: 'Erreur lecture Firestore: $e',
        severity: CartValidationSeverity.error,
      ));
    }

    return errors;
  }
}
