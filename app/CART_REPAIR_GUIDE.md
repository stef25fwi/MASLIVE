# Cart Coherence Repair Guide

## Overview

The cart coherence system provides automated verification and repair of cart data integrity issues.

## Quick Start

### 1. Check Cart Health
```dart
import 'package:masslive/utils/cart_health_check.dart';

// Simple check without repair
final result = CartHealthCheck.check();
print('Healthy: ${result.isHealthy}');
print('Status: ${result.statusMessage}');
```

### 2. Full Health Check with Auto-Repair
```dart
// Check and auto-repair critical issues
final result = await CartHealthCheck.perform();
print(result.getDetailedReport());
```

### 3. Quick Repair Only
```dart
// Just repair without verification
final report = await CartHealthCheck.quickRepair();
print(report.summary);
```

## Repair Capabilities

The repair system automatically fixes:

| Issue | Fix |
|-------|-----|
| Empty ID | Generate `ci_<timestamp>` |
| Empty productId | Use `'unknown'` |
| Empty title | Use `'Article'` |
| Empty currency | Use `'EUR'` |
| Quantity < 1 or > 999 | Clamp to 1-999 |
| Negative unitPrice | Set to 0 |
| Media: isDigital=false | Change to true |
| Media: requiresShipping=true | Change to false |
| Merch: isDigital=true | Change to false |
| Merch: requiresShipping=false | Change to true |
| Duplicate item IDs | Remove duplicates |

## Verification Checks

### Critical Issues (will prevent checkout)
- ❌ Missing required fields
- ❌ Invalid quantity (< 1 or > 999)
- ❌ Negative pricing
- ❌ Media with requiresShipping=true
- ❌ Duplicate item IDs

### Warnings (advisory)
- ⚠ Multiple currencies
- ⚠ Non-standard ID format
- ⚠ Merch with incorrect flags
- ⚠ Media with incorrect flags

## Usage Examples

### Before Checkout
```dart
import 'package:masslive/utils/cart_health_check.dart';

Future<bool> canCheckout() async {
  final result = await CartHealthCheck.perform();

  if (!result.isHealthy) {
    print('Cannot checkout:');
    print(result.getDetailedReport());
    return false;
  }

  return true;
}
```

### In Cart Provider
```dart
class CartProvider extends ChangeNotifier {
  Future<void> validateAndRepair() async {
    final result = await CartHealthCheck.perform();

    if (result.repairReport != null && result.repairReport!.repaidCount > 0) {
      debugPrint('Repairs applied: ${result.repairReport!.summary}');
    }

    if (!result.isHealthy) {
      error = result.getDetailedReport();
      notifyListeners();
    }
  }
}
```

### For Testing
```dart
test('cart is coherent after operations', () async {
  // ... perform cart operations ...

  final result = CartHealthCheck.check();
  expect(result.isHealthy, true,
         reason: result.getDetailedReport());
});
```

## Report Structure

### CartHealthResult
```
- isHealthy: bool - Whether cart is valid
- issues: List<CartCoherenceIssue> - Remaining issues
- repairReport: CartRepairReport? - What was repaired
- statusMessage: String - Human-readable status
- criticalIssuesCount: int - Count of critical issues
- warningCount: int - Count of warnings
- getDetailedReport(): String - Full report with details
```

### CartRepairReport
```
- repaidCount: int - Number of issues fixed
- fixedCritical: int - Number of critical issues fixed
- totalItems: int - Total items in cart
- summary: String - Formatted summary report
```

## Integration Points

### Before Initialization
```dart
await CartProvider.instance.init(uid);
await CartHealthCheck.perform();
```

### Before Checkout
```dart
final result = await CartHealthCheck.perform();
if (!result.isHealthy) {
  // Show error to user
}
```

### Periodic Monitoring
```dart
// Schedule periodic checks (e.g., every 5 minutes)
Timer.periodic(Duration(minutes: 5), (_) async {
  await CartHealthCheck.perform();
});
```

## Logs & Debugging

Enable debug logging to see repair details:
```dart
if (kDebugMode) {
  final result = await CartHealthCheck.perform();
  print(result.getDetailedReport());
}
```

## Performance Notes

- ✓ Verification is O(n) - scans all items once
- ✓ Repair is O(n) with async updates to Firestore
- ✓ Duplicate detection uses HashSet for O(1) lookups
- ✓ Safe for regular execution (no heavy operations)

## Error Handling

```dart
try {
  final result = await CartHealthCheck.perform();
  print(result.statusMessage);
} catch (e, st) {
  debugPrint('Health check failed: $e');
  debugPrintStack(stackTrace: st);
}
```

## Testing

Comprehensive tests are available in:
- `test/utils/cart_coherence_checker_test.dart`
- `test/utils/cart_health_check_test.dart` (if you create it)

Run tests:
```bash
flutter test test/utils/
```
