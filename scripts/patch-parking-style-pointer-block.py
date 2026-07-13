from pathlib import Path

path = Path('app/lib/admin/parking_zone_drawer_page.dart')
s = path.read_text()

if "package:pointer_interceptor/pointer_interceptor.dart" not in s:
    s = s.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:pointer_interceptor/pointer_interceptor.dart';\n",
        1,
    )

s = s.replace(
    "  bool _saving = false;\n",
    "  bool _saving = false;\n  bool _styleSheetOpen = false;\n",
    1,
)

s = s.replace(
    "  void _onMapTap(MapPoint pt) {\n    setState(() {\n",
    "  void _onMapTap(MapPoint pt) {\n    if (_styleSheetOpen || _saving) return;\n    setState(() {\n",
    1,
)

old = """  void _openStyleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _StyleSheet(
        nameCtrl: _nameCtrl,
        fillColorCtrl: _fillColorCtrl,
        strokeColorCtrl: _strokeColorCtrl,
        vehicleTypes: _vehicleTypes,
        strokeFollowsFill: _strokeFollowsFill,
        colorSaturation: _colorSaturation,
        fillOpacity: _fillOpacity,
        strokeWidth: _strokeWidth,
        strokeDash: _strokeDash,
        pattern: _pattern,
        patternOpacity: _patternOpacity,
        pointCount: _points.length,
        error: _error,
        saving: _saving,
        onStyleChanged: _onStyleChanged,
        onSave: _save,
      ),
    ).then((_) => setState(() {}));
  }
"""
new = """  Future<void> _openStyleSheet() async {
    if (_styleSheetOpen) return;
    setState(() => _styleSheetOpen = true);

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: _StyleSheet(
                nameCtrl: _nameCtrl,
                fillColorCtrl: _fillColorCtrl,
                strokeColorCtrl: _strokeColorCtrl,
                vehicleTypes: _vehicleTypes,
                strokeFollowsFill: _strokeFollowsFill,
                colorSaturation: _colorSaturation,
                fillOpacity: _fillOpacity,
                strokeWidth: _strokeWidth,
                strokeDash: _strokeDash,
                pattern: _pattern,
                patternOpacity: _patternOpacity,
                pointCount: _points.length,
                error: _error,
                saving: _saving,
                onStyleChanged: _onStyleChanged,
                onSave: _save,
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _styleSheetOpen = false);
      }
    }
  }
"""
if old not in s:
    raise SystemExit('style sheet block not found')
s = s.replace(old, new, 1)

path.write_text(s)

test = Path('app/test/admin/parking_style_sheet_pointer_test.dart')
test.parent.mkdir(parents=True, exist_ok=True)
test.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parking style sheet blocks taps from reaching the map', () {
    final source = File('lib/admin/parking_zone_drawer_page.dart')
        .readAsStringSync();

    expect(source, contains('PointerInterceptor('));
    expect(source, contains('HitTestBehavior.opaque'));
    expect(source, contains('if (_styleSheetOpen || _saving) return;'));
    expect(source, contains('setState(() => _styleSheetOpen = true)'));
    expect(source, contains('setState(() => _styleSheetOpen = false)'));
  });
}
""")
