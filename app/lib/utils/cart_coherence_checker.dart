import '../models/cart_item_model.dart';
import '../services/cart_service.dart';

/// Utility class to verify cart coherence and data integrity.
class CartCoherenceChecker {
  static const String _okMark = '✓';
  static const String _failMark = '✗';

  static bool _hasMerchImage(CartItemModel item) {
    final imageUrl = item.imageUrl.trim();
    if (imageUrl.isNotEmpty) return true;

    final metadata = item.metadata;
    if (metadata == null) return false;

    return (metadata['imagePath'] ?? '').toString().trim().isNotEmpty;
  }

  /// Checks if all carts are coherent.
  /// Returns a list of coherence issues found.
  static List<CartCoherenceIssue> verify() {
    final issues = <CartCoherenceIssue>[];

    final items = CartService.instance.unifiedItems;

    // Check 1: All items have valid required fields
    for (final (index, item) in items.indexed) {
      _checkItemRequiredFields(item, index, issues);
    }

    // Check 2: Quantity values are within safe ranges
    for (final (index, item) in items.indexed) {
      _checkItemQuantity(item, index, issues);
    }

    // Check 3: Unit prices are non-negative
    for (final (index, item) in items.indexed) {
      _checkItemPrice(item, index, issues);
    }

    // Check 4: Currency consistency
    _checkCurrencyConsistency(items, issues);

    // Check 5: No duplicate items (same product/size/color)
    _checkNoDuplicates(items, issues);

    // Check 6: Media items have correct flags
    for (final (index, item) in items.indexed) {
      _checkMediaItemFlags(item, index, issues);
    }

    // Check 7: Merch items have correct flags
    for (final (index, item) in items.indexed) {
      _checkMerchItemFlags(item, index, issues);
    }

    // Check 8: Item IDs are correctly formatted
    for (final (index, item) in items.indexed) {
      _checkItemIdFormat(item, index, issues);
    }

    return issues;
  }

  static void _checkItemRequiredFields(
    CartItemModel item,
    int index,
    List<CartCoherenceIssue> issues,
  ) {
    final requiredFields = <String>[];

    if (item.id.isEmpty) requiredFields.add('id');
    if (item.productId.isEmpty) requiredFields.add('productId');
    if (item.title.isEmpty) requiredFields.add('title');
    if (item.itemType == CartItemType.merch && !_hasMerchImage(item)) {
      requiredFields.add('imageUrl');
    }
    if (item.currency.isEmpty) requiredFields.add('currency');

    if (requiredFields.isNotEmpty) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.critical,
          item: item,
          message:
              'Item $index has empty required fields: ${requiredFields.join(', ')}',
        ),
      );
    }
  }

  static void _checkItemQuantity(
    CartItemModel item,
    int index,
    List<CartCoherenceIssue> issues,
  ) {
    if (item.quantity < 1 || item.quantity > 999) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.critical,
          item: item,
          message:
              'Item $index (${item.title}) has invalid quantity: ${item.quantity} (must be 1-999)',
        ),
      );
    }
  }

  static void _checkItemPrice(
    CartItemModel item,
    int index,
    List<CartCoherenceIssue> issues,
  ) {
    if (item.unitPrice < 0) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.critical,
          item: item,
          message:
              'Item $index (${item.title}) has negative price: €${item.unitPrice}',
        ),
      );
    }
  }

  static void _checkCurrencyConsistency(
    List<CartItemModel> items,
    List<CartCoherenceIssue> issues,
  ) {
    if (items.isEmpty) return;

    final currencies = items.map((item) => item.currency).toSet();

    if (currencies.length > 1) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.warning,
          message:
              'Cart contains multiple currencies: ${currencies.join(', ')}',
        ),
      );
    }

    for (final currency in currencies) {
      if (!['EUR', 'USD', 'GBP'].contains(currency)) {
        issues.add(
          CartCoherenceIssue(
            severity: CoherenceSeverity.warning,
            message: 'Unexpected currency code: $currency',
          ),
        );
      }
    }
  }

  static void _checkNoDuplicates(
    List<CartItemModel> items,
    List<CartCoherenceIssue> issues,
  ) {
    final seenIds = <String>{};

    for (final item in items) {
      if (seenIds.contains(item.id)) {
        issues.add(
          CartCoherenceIssue(
            severity: CoherenceSeverity.critical,
            item: item,
            message: 'Duplicate item ID found: ${item.id}',
          ),
        );
      }
      seenIds.add(item.id);
    }
  }

  static void _checkMediaItemFlags(
    CartItemModel item,
    int index,
    List<CartCoherenceIssue> issues,
  ) {
    if (item.itemType != CartItemType.media) return;

    if (!item.isDigital) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.warning,
          item: item,
          message: 'Media item $index (${item.title}) has isDigital=false',
        ),
      );
    }

    if (item.requiresShipping) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.critical,
          item: item,
          message:
              'Media item $index (${item.title}) has requiresShipping=true',
        ),
      );
    }
  }

  static void _checkMerchItemFlags(
    CartItemModel item,
    int index,
    List<CartCoherenceIssue> issues,
  ) {
    if (item.itemType != CartItemType.merch) return;

    if (item.isDigital) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.warning,
          item: item,
          message: 'Merch item $index (${item.title}) has isDigital=true',
        ),
      );
    }

    if (!item.requiresShipping) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.warning,
          item: item,
          message:
              'Merch item $index (${item.title}) has requiresShipping=false',
        ),
      );
    }
  }

  static void _checkItemIdFormat(
    CartItemModel item,
    int index,
    List<CartCoherenceIssue> issues,
  ) {
    // Item IDs should start with 'ci_' and be 45 characters total (ci_ + 40 char sha1)
    if (!item.id.startsWith('ci_') || item.id.length != 43) {
      issues.add(
        CartCoherenceIssue(
          severity: CoherenceSeverity.warning,
          item: item,
          message:
              'Item $index (${item.title}) has non-standard ID format: ${item.id} (expected ci_ + sha1)',
        ),
      );
    }
  }

  /// Prints a human-readable report of coherence issues.
  static String printReport(List<CartCoherenceIssue> issues) {
    if (issues.isEmpty) {
      return '$_okMark All carts are coherent!';
    }

    final critique = StringBuffer();
    critique.writeln('$_failMark Cart Coherence Report:');
    critique.writeln('Found ${issues.length} issue(s)\n');

    final critical = issues.where(
      (e) => e.severity == CoherenceSeverity.critical,
    );
    final warnings = issues.where(
      (e) => e.severity == CoherenceSeverity.warning,
    );

    if (critical.isNotEmpty) {
      critique.writeln('Critical Issues (${critical.length}):');
      for (final issue in critical) {
        critique.writeln('  $_failMark ${issue.message}');
      }
      critique.writeln();
    }

    if (warnings.isNotEmpty) {
      critique.writeln('Warnings (${warnings.length}):');
      for (final issue in warnings) {
        critique.writeln('  ⚠  ${issue.message}');
      }
    }

    return critique.toString();
  }

  /// Repairs cart coherence issues automatically.
  /// Returns a report of repairs made.
  static Future<CartRepairReport> repair() async {
    final report = CartRepairReport();
    final service = CartService.instance;
    final items = List<CartItemModel>.from(service.unifiedItems);

    final seenIds = <String>{};
    final itemsToRemove = <String>[];

    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      final originalItem = item;

      // 1. Fix required fields
      item = _repairRequiredFields(item);

      // 2. Fix quantity
      if (item.quantity < 1 || item.quantity > 999) {
        final clamped = item.quantity.clamp(1, 999);
        report.addRepair(
          'Item ${item.title}: quantity fixed ${item.quantity} → $clamped',
        );
        item = item.copyWith(quantity: clamped);
      }

      // 3. Fix negative prices
      if (item.unitPrice < 0) {
        report.addRepair(
          'Item ${item.title}: negative price fixed €${item.unitPrice} → €0',
        );
        item = item.copyWith(unitPrice: 0);
      }

      // 4. Fix media item flags
      if (item.itemType == CartItemType.media) {
        var mediaFixed = false;
        if (!item.isDigital) {
          report.addRepair(
            'Item ${item.title}: media flag fixed (isDigital: false → true)',
          );
          item = item.copyWith(isDigital: true);
          mediaFixed = true;
        }
        if (item.requiresShipping) {
          report.addRepair(
            'Item ${item.title}: media shipping flag fixed (requiresShipping: true → false)',
          );
          item = item.copyWith(requiresShipping: false);
          mediaFixed = true;
        }
        if (mediaFixed) {
          report.fixedCritical++;
        }
      }

      // 5. Fix merch item flags
      if (item.itemType == CartItemType.merch) {
        if (item.isDigital) {
          report.addRepair(
            'Item ${item.title}: merch digital flag fixed (isDigital: true → false)',
          );
          item = item.copyWith(isDigital: false);
          report.fixedCritical++;
        }
        if (!item.requiresShipping && !item.isDigital) {
          report.addRepair(
            'Item ${item.title}: merch shipping flag fixed (requiresShipping: false → true)',
          );
          item = item.copyWith(requiresShipping: true);
          report.fixedCritical++;
        }
      }

      // 6. Check for duplicate IDs
      if (seenIds.contains(item.id)) {
        report.addRepair(
          'Duplicate item ID removed: ${item.id} (${item.title})',
        );
        itemsToRemove.add(item.id);
        report.fixedCritical++;
        continue;
      }
      seenIds.add(item.id);

      // Update item if it was modified
      if (item != originalItem) {
        items[i] = item;
        await service.updateCartItemQuantity(item.id, item.safeQuantity);
      }
    }

    // 7. Remove duplicate items
    for (final itemId in itemsToRemove) {
      await service.removeCartItem(itemId);
    }

    report.totalItems = items.length;
    return report;
  }

  static CartItemModel _repairRequiredFields(CartItemModel item) {
    var repaired = item;
    var changed = false;

    if (repaired.id.isEmpty) {
      repaired = repaired.copyWith(
        id: 'ci_${DateTime.now().millisecondsSinceEpoch}',
      );
      changed = true;
    }

    if (repaired.productId.isEmpty) {
      repaired = repaired.copyWith(productId: 'unknown');
      changed = true;
    }

    if (repaired.title.isEmpty) {
      repaired = repaired.copyWith(title: 'Article');
      changed = true;
    }

    if (repaired.currency.isEmpty) {
      repaired = repaired.copyWith(currency: 'EUR');
      changed = true;
    }

    if (changed) {
      return repaired;
    }

    return item;
  }
}

enum CoherenceSeverity { critical, warning }

class CartCoherenceIssue {
  final CoherenceSeverity severity;
  final CartItemModel? item;
  final String message;

  CartCoherenceIssue({
    required this.severity,
    this.item,
    required this.message,
  });

  @override
  String toString() => message;
}

class CartRepairReport {
  final List<String> _repairs = [];
  int fixedCritical = 0;
  int totalItems = 0;

  void addRepair(String repair) {
    _repairs.add(repair);
  }

  int get repaidCount => _repairs.length;

  String get summary {
    if (_repairs.isEmpty) {
      return '✓ No repairs needed - cart is coherent!';
    }

    final buffer = StringBuffer();
    buffer.writeln('✓ Cart Repair Report');
    buffer.writeln(
      'Fixed $repaidCount issue(s) across $totalItems item(s)\n',
    );
    buffer.writeln('Repairs Applied:');
    for (final repair in _repairs) {
      buffer.writeln('  ✓ $repair');
    }

    if (fixedCritical > 0) {
      buffer.writeln('\nCritical Issues Fixed: $fixedCritical');
    }

    return buffer.toString();
  }
}
