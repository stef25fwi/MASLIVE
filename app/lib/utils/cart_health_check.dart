import 'cart_coherence_checker.dart';

/// Convenience utility for managing cart coherence verification and repair.
class CartHealthCheck {
  static Future<CartHealthResult> perform() async {
    final issues = CartCoherenceChecker.verify();

    if (issues.isEmpty) {
      return CartHealthResult(
        isHealthy: true,
        issues: const [],
        repairReport: null,
      );
    }

    // Auto-repair critical issues
    final report = await CartCoherenceChecker.repair();

    // Verify again after repair
    final remainingIssues = CartCoherenceChecker.verify();

    return CartHealthResult(
      isHealthy: remainingIssues.isEmpty,
      issues: remainingIssues,
      repairReport: report,
    );
  }

  /// Only checks without repairing.
  static CartHealthResult check() {
    final issues = CartCoherenceChecker.verify();
    return CartHealthResult(
      isHealthy: issues.isEmpty,
      issues: issues,
      repairReport: null,
    );
  }

  /// Only repairs without checking afterward.
  static Future<CartRepairReport> quickRepair() {
    return CartCoherenceChecker.repair();
  }
}

class CartHealthResult {
  final bool isHealthy;
  final List<CartCoherenceIssue> issues;
  final CartRepairReport? repairReport;

  CartHealthResult({
    required this.isHealthy,
    required this.issues,
    required this.repairReport,
  });

  int get criticalIssuesCount =>
      issues.where((i) => i.severity == CoherenceSeverity.critical).length;

  int get warningCount =>
      issues.where((i) => i.severity == CoherenceSeverity.warning).length;

  String get statusMessage {
    if (isHealthy) {
      if (repairReport != null && repairReport!.repaidCount > 0) {
        return 'Cart repaired: ${repairReport!.repaidCount} issue(s) fixed';
      }
      return 'Cart is healthy';
    }
    return 'Cart has $criticalIssuesCount critical issue(s) and $warningCount warning(s)';
  }

  String getDetailedReport() {
    final buffer = StringBuffer();

    if (repairReport != null && repairReport!.repaidCount > 0) {
      buffer.writeln('═══ REPAIR REPORT ═══');
      buffer.writeln(repairReport!.summary);
      buffer.writeln();
    }

    if (issues.isNotEmpty) {
      buffer.writeln('═══ REMAINING ISSUES ═══');
      buffer.writeln(CartCoherenceChecker.printReport(issues));
    }

    if (isHealthy && (repairReport == null || repairReport!.repaidCount == 0)) {
      buffer.writeln('✓ Cart is coherent - no issues found');
    }

    return buffer.toString();
  }
}
