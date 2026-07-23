import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String relativePath) => File(relativePath).readAsStringSync();

  test('admin dashboard is centered and constrained on large screens', () {
    final dashboard = source('lib/admin/admin_main_dashboard.dart');

    expect(dashboard, contains('ResponsivePageContainer('));
    expect(dashboard, contains('maxContentWidth: 1440'));
    expect(dashboard, contains('wide: const EdgeInsets.fromLTRB(44, 28, 44, 36)'));
  });

  test('admin analytics uses adaptive metric columns', () {
    final analytics = source('lib/admin/admin_analytics_page.dart');

    expect(analytics, contains('maxContentWidth: 1280'));
    expect(analytics, contains('compact: 2'));
    expect(analytics, contains('medium: 3'));
    expect(analytics, contains('expanded: 4'));
    expect(analytics, contains('wide: 4'));
  });

  test('orders and tracking live remain compact-first', () {
    final orders = source('lib/admin/admin_orders_page.dart');
    final tracking = source(
      'lib/admin/tracking_live/tracking_live_page.dart',
    );

    expect(orders, contains('maxContentWidth: 1280'));
    expect(tracking, contains('maxContentWidth: 1440'));
    expect(tracking, contains('context.isCompactLayout'));
  });

  test('circuit wizard constrains lists and long forms', () {
    final wizard = source('lib/admin/circuit_wizard_entry_page.dart');

    expect(wizard, contains('maxContentWidth: 1200'));
    expect(wizard, contains('medium: 760'));
    expect(wizard, contains('expanded: 900'));
    expect(wizard, contains('wide: 980'));
  });
}
