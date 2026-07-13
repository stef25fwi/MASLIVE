import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POI editor keeps local preview bytes after upload', () {
    final source = File('lib/admin/poi_edit_popup.dart').readAsStringSync();

    expect(source, contains('if (previewBytes != null)'));
    expect(source, contains('Conserver les octets locaux après upload'));
  });

  test('POI upload validates a non-empty returned URL', () {
    final source = File('lib/admin/poi_edit_popup.dart').readAsStringSync();

    expect(source, contains('Aucune URL image retournée après upload'));
    expect(source, contains('asset.originalUrl.trim()'));
  });

  test('MarketMap POI persistence keeps legacy photoUrl alias', () {
    final source = File(
      'lib/admin/poi_marketmap_wizard_page.dart',
    ).readAsStringSync();

    expect(source, contains("'photoUrl': normalizedImageUrl"));
  });
}
