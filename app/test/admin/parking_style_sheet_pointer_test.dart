import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parking style sheet blocks taps from reaching the map', () {
    final source = File(
      'lib/admin/parking_zone_drawer_page.dart',
    ).readAsStringSync();

    expect(source, contains('PointerInterceptor('));
    expect(source, contains('HitTestBehavior.opaque'));
    expect(source, contains('onTap: () {}'));
    expect(source, contains('if (_styleSheetOpen || _saving) return;'));
    expect(source, contains('setState(() => _styleSheetOpen = true)'));
    expect(source, contains('setState(() => _styleSheetOpen = false)'));
  });
}
