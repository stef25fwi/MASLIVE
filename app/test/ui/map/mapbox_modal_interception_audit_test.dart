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
        reason:
            'Web and native implementations must receive the guarded tap callback.',
      );
      expect(
        source,
        isNot(contains('onTap: onTap,')),
        reason:
            'The raw callback must never be forwarded by the shared map wrapper.',
      );
    });

    test('known map-backed modal surfaces keep pointer interception', () {
      final circuitDialog = File(
        'lib/admin/circuit_wizard_entry_page.dart',
      ).readAsStringSync();
      expect(
        circuitDialog,
        contains("package:pointer_interceptor/pointer_interceptor.dart"),
      );
      expect(circuitDialog, contains('PointerInterceptor('));

      final parkingRegression = File(
        'test/admin/parking_style_sheet_pointer_test.dart',
      ).readAsStringSync();
      expect(parkingRegression, contains('blocks taps from reaching the map'));

      final sharedGuardRegression = File(
        'test/ui/map/maslive_map_modal_tap_guard_test.dart',
      ).readAsStringSync();
      expect(
        sharedGuardRegression,
        contains('ignores taps while another modal route is active'),
      );
    });

    test('new direct Mapbox integrations must be added to the audited inventory', () {
      const auditedDirectIntegrations = <String>{
        'lib/ui/map/maslive_map.dart',
        'lib/ui/map/maslive_map_native.dart',
        'lib/ui/map/maslive_map_web.dart',
        'lib/ui/map/maslive_map_web_stub.dart',
        'lib/services/mapbox_polyline_snap_service.dart',
        'lib/services/mapbox_directions_service.dart',
        'lib/pages/tracking_live_page.dart',
        'lib/pages/public/marketmap_public_viewer_page.dart',
        'lib/pages/home_map_page_3d.dart',
        'lib/pages/circuit_draw_page.dart',
        'lib/pages/add_place_page.dart',
        'lib/models/draft_circuit.dart',
        'lib/admin/admin_circuits_page.dart',
        'lib/providers/wizard_circuit_provider.dart',
        'lib/ui/widgets/mapbox_native_simple_map.dart',
        'lib/ui/widgets/mapbox_live_tracking_layer.dart',
        'lib/ui/google_light_map_page.dart',
        'lib/route_style_pro/services/map_buildings_style_service_native.dart',
        'lib/route_style_pro/ui/widgets/route_style_preview_map.dart',
      };

      final directIntegrationPatterns = <RegExp>[
        RegExp(r"package:mapbox_maps_flutter"),
        RegExp(r'\bMasLiveMapNative\s*\('),
        RegExp(r'\bMasLiveMapWeb\s*\('),
        RegExp(r'\bMapWidget\s*\('),
        RegExp(r'\bMapboxMap\s*\('),
      ];

      final unaudited = <String>[];
      final dartFiles = Directory('lib')
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final relativePath = file.path.replaceAll('\\', '/');
        final source = file.readAsStringSync();
        final hasDirectIntegration = directIntegrationPatterns.any(
          (pattern) => pattern.hasMatch(source),
        );
        if (hasDirectIntegration &&
            !auditedDirectIntegrations.contains(relativePath)) {
          unaudited.add(relativePath);
        }
      }

      expect(
        unaudited,
        isEmpty,
        reason:
            'A new direct Mapbox integration was introduced outside the audited inventory. Review its modal pointer interception before adding it here.\n${unaudited.join('\n')}',
      );
    });
  });
}
