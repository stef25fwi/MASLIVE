import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Contract executed after all shared and page-level Mapbox overlays are wrapped.
void main() {
  String source(String relativePath) => File(relativePath).readAsStringSync();

  test('shared POI overlays intercept pointers above Mapbox', () {
    final polaroid = source('lib/ui/widgets/polaroid_poi_sheet.dart');
    final selector = source(
      'lib/ui/widgets/marketmap_poi_selector_sheet.dart',
    );

    expect(polaroid, contains('PointerInterceptor(child: SafeArea('));
    expect(selector, contains('PointerInterceptor('));
    expect(selector, contains('child: _MarketMapPoiSelectorSheet('));
  });

  test('POI editor locks preview map while nested overlays are open', () {
    final editor = source('lib/admin/poi_edit_popup.dart');

    expect(editor, contains('bool _interactionOverlayOpen = false'));
    expect(editor, contains('_withInteractionLock'));
    expect(
      editor,
      contains('if (_interactionOverlayOpen || _isSaving || _isUploading) return;'),
    );
    expect(editor, contains('PointerInterceptor(child: AlertDialog('));
    expect(editor, contains('PointerInterceptor(child: SafeArea('));
    expect(editor, contains('return PointerInterceptor('));
  });

  test('circuit editor blocks point creation behind dialogs', () {
    final editor = source('lib/admin/circuit_map_editor.dart');

    expect(editor, contains('bool _interactionOverlayOpen = false'));
    expect(
      editor,
      contains('if (_interactionOverlayOpen || !widget.editingEnabled) return;'),
    );
    expect(editor, contains('PointerInterceptor(child: AlertDialog('));
    expect(editor, contains('_withInteractionLock'));
  });

  test('all known map administration overlays remain protected', () {
    final parking = source('lib/admin/parking_zone_drawer_page.dart');
    final defaultMap = source('lib/pages/default_map_page.dart');
    final wizard = source('lib/admin/circuit_wizard_pro_page.dart');
    final entry = source('lib/admin/circuit_wizard_entry_page.dart');

    expect(parking, contains('if (_styleSheetOpen || _saving) return;'));
    expect(parking, contains('builder: (ctx) => PointerInterceptor('));
    expect(defaultMap, contains('PointerInterceptor('));
    expect(wizard, contains('PointerInterceptor('));
    expect(entry, contains('return PointerInterceptor('));
  });
}
