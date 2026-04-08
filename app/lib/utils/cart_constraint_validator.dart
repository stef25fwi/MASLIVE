import '../models/cart_item_model.dart';

/// Validator for cart constraints and business rules.
/// Ensures items meet all requirements before being added to cart.
class CartConstraintValidator {
  /// Validates quantity based on item type and business rules.
  static (bool valid, String? error) validateQuantity(
    CartItemModel item,
    int newQuantity,
  ) {
    if (item.itemType == CartItemType.media) {
      if (newQuantity != 1) {
        return (false, 'Media items must keep quantity = 1');
      }
      return (true, null);
    }

    if (newQuantity < 1 || newQuantity > 999) {
      return (false, 'Quantity must be between 1 and 999');
    }

    return (true, null);
  }

  /// Validates currency consistency with existing cart items.
  /// Prevents mixing different currencies in same cart.
  static (bool valid, String? error) validateCurrency(
    CartItemModel newItem,
    List<CartItemModel> existingItems,
  ) {
    if (existingItems.isEmpty) {
      return (true, null);
    }

    // All items in cart must have same currency
    final cartCurrency = existingItems.first.currency;

    if (newItem.currency != cartCurrency) {
      return (
        false,
        'Cannot mix currencies. Cart uses $cartCurrency, item is ${newItem.currency}'
      );
    }

    return (true, null);
  }

  /// Validates metadata consistency for item type.
  /// Ensures required metadata fields are present.
  static (bool valid, String? error) validateMetadata(CartItemModel item) {
    final metadata = item.metadata ?? const <String, dynamic>{};

    switch (item.itemType) {
      case CartItemType.merch:
        // Merch should have size and color in metadata
        final hasSize = metadata.containsKey('size') &&
                       (metadata['size'] as String?)?.isNotEmpty == true;
        final hasColor = metadata.containsKey('color') &&
                        (metadata['color'] as String?)?.isNotEmpty == true;

        if (!hasSize || !hasColor) {
          return (
            false,
            'Merch items require size and color in metadata'
          );
        }

        return (true, null);

      case CartItemType.media:
        // Media should have assetType if available
        if (metadata.isEmpty) {
          return (true, null); // Optional for media
        }

        final hasAssetType = metadata.containsKey('assetType');
        if (hasAssetType &&
            (metadata['assetType'] as String?)?.isEmpty == true) {
          return (false, 'assetType cannot be empty');
        }

        return (true, null);
    }
  }

  /// Validates item type specific rules.
  static (bool valid, String? error) validateItemTypeRules(CartItemModel item) {
    if (item.itemType == CartItemType.media) {
      // Media items must be digital
      if (!item.isDigital) {
        return (false, 'Media items must have isDigital=true');
      }

      // Media items must not require shipping
      if (item.requiresShipping) {
        return (false, 'Media items must have requiresShipping=false');
      }

      return (true, null);
    }

    // Merch items must NOT be digital
    if (item.isDigital) {
      return (false, 'Merch items must have isDigital=false');
    }

    // Merch items MUST require shipping
    if (!item.requiresShipping) {
      return (false, 'Merch items must have requiresShipping=true');
    }

    return (true, null);
  }

  /// Validates pricing constraints.
  static (bool valid, String? error) validatePricing(CartItemModel item) {
    if (item.unitPrice < 0) {
      return (false, 'Unit price cannot be negative');
    }

    // Zero prices allowed (free items)
    return (true, null);
  }

  /// Complete validation of item before adding to cart.
  /// Returns validation result with detailed error message.
  static CartValidationResult validateItemForCart(
    CartItemModel item,
    List<CartItemModel> existingItems,
  ) {
    // Check required fields
    if (item.id.isEmpty) {
      return CartValidationResult(
        valid: false,
        error: 'Item ID cannot be empty',
      );
    }

    if (item.productId.isEmpty) {
      return CartValidationResult(
        valid: false,
        error: 'Product ID is required',
      );
    }

    if (item.title.isEmpty) {
      return CartValidationResult(
        valid: false,
        error: 'Item title cannot be empty',
      );
    }

    // Validate quantity
    final (quantityValid, quantityError) = validateQuantity(item, item.quantity);
    if (!quantityValid) {
      return CartValidationResult(valid: false, error: quantityError);
    }

    // Validate currency consistency
    final (currencyValid, currencyError) = validateCurrency(item, existingItems);
    if (!currencyValid) {
      return CartValidationResult(valid: false, error: currencyError);
    }

    // Validate item type rules
    final (typeValid, typeError) = validateItemTypeRules(item);
    if (!typeValid) {
      return CartValidationResult(valid: false, error: typeError);
    }

    // Validate pricing
    final (priceValid, priceError) = validatePricing(item);
    if (!priceValid) {
      return CartValidationResult(valid: false, error: priceError);
    }

    // Validate metadata
    final (metaValid, metaError) = validateMetadata(item);
    if (!metaValid) {
      return CartValidationResult(valid: false, error: metaError);
    }

    return CartValidationResult(valid: true);
  }
}

class CartValidationResult {
  final bool valid;
  final String? error;

  CartValidationResult({
    required this.valid,
    this.error,
  });

  @override
  String toString() => valid ? 'Valid' : 'Invalid: $error';
}
