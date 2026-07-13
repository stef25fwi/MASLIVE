import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POI upload guards the captured BuildContext after async work', () {
    final source = File('lib/admin/poi_edit_popup.dart').readAsStringSync();
    expect(source, contains('if (!context.mounted) return;'));
  });

  test('POI parser uses braces for string conversion branch', () {
    final source = File(
      'lib/admin/poi_marketmap_wizard_page.dart',
    ).readAsStringSync();
    expect(source, contains('if (v is String) {'));
  });

  test('product images use the non-deprecated reorder callback', () {
    final source = File(
      'lib/features/commerce/presentation/pages/product_management_page.dart',
    ).readAsStringSync();
    expect(source, contains('onReorderItem:'));
    expect(source, isNot(contains('onReorder: (oldIndex, newIndex)')));
  });
}
