import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mapbox modal interception audit', () {
    test('the shared map wrapper blocks taps while a modal route is active', () {
      final source = File('lib/ui/map/maslive_map.dart').readAsStringSync();

      expect(source, contains('ValueChanged<MapPoint>? _guardMapTap'));
      expect(source, contains('final route = ModalRoute.of(context);'));
      expect(source, contains('if (route != null && !route.isCurrent) return;'));
      expect(
        RegExp(r'onTap:\s*guardedOnTap').allMatches(source).length,
        greaterThanOrEqualTo(2),
        reason: 'Web and native implementations must receive the guarded tap callback.',
      );
      expect(
        source,
        isNot(contains('onTap: onTap,')),
        reason: 'The raw callback must never be forwarded to a Mapbox implementation.',
      );
    });

    test('feature screens cannot bypass the protected MasLiveMap wrapper', () {
      const allowedIntegrationFiles = <String>{
        'lib/ui/map/maslive_map.dart',
        'lib/ui/map/maslive_map_native.dart',
        'lib/ui/map/maslive_map_web.dart',
        'lib/ui/map/maslive_map_web_stub.dart',
      };

      final forbiddenIntegrations = <RegExp, String>{
        RegExp(r"package:mapbox_maps_flutter"): 'direct mapbox_maps_flutter import',
        RegExp(r'\bMasLiveMapNative\s*\('): 'direct MasLiveMapNative construction',
        RegExp(r'\bMasLiveMapWeb\s*\('): 'direct MasLiveMapWeb construction',
        RegExp(r'\bMapWidget\s*\('): 'direct MapWidget construction',
        RegExp(r'\bMapboxMap\s*\('): 'direct MapboxMap construction',
      };

      final violations = <String>[];
      final dartFiles = Directory('lib')
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final relativePath = file.path.replaceAll('\\', '/');
        if (allowedIntegrationFiles.contains(relativePath)) continue;

        final source = file.readAsStringSync();
        for (final entry in forbiddenIntegrations.entries) {
          if (entry.key.hasMatch(source)) {
            violations.add('$relativePath — ${entry.value}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Every feature screen must use MasLiveMap so dialogs, sheets and popup routes cannot leak taps to Mapbox.\n${violations.join('\n')}',
      );
    });
  });
}
