import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'mapbox_native_circuit_map.dart';
import 'mapbox_web_circuit_map.dart';

typedef LngLat = ({double lng, double lat});

Widget buildCircuitMap({
  required List<LngLat> perimeter,
  required List<LngLat> route,
  required List<({int startIndex, int endIndex, Color color, String name})>
      segments,
  required bool locked,
  required ValueChanged<LngLat> onTap,
  String? mapboxToken,
}) {
  if (kIsWeb) {
    final envToken = const String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    final legacyEnvToken = const String.fromEnvironment('MAPBOX_TOKEN');
    return MapboxWebCircuitMap(
      mapboxToken:
          mapboxToken ?? (envToken.isNotEmpty ? envToken : legacyEnvToken),
      perimeter: perimeter,
      route: route,
      segments: segments,
      onTapLngLat: onTap,
    );
  }
  return MapboxNativeCircuitMap(
    perimeter: perimeter,
    route: route,
    segments: segments,
    locked: locked,
    onTapLngLat: onTap,
  );
}
