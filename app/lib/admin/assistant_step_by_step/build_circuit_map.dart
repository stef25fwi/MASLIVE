import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../services/mapbox_token_service.dart';
import 'mapbox_native_circuit_map.dart';
import 'mapbox_web_circuit_map_stub.dart'
  if (dart.library.html) 'mapbox_web_circuit_map.dart';

typedef LngLat = ({double lng, double lat});

Widget buildCircuitMap({
  required List<LngLat> perimeter,
  required List<LngLat> route,
  required List<({int startIndex, int endIndex, Color color, String name})>
  segments,
  required bool locked,
  required ValueChanged<LngLat> onTap,
  bool showMask = false,
  String? mapboxToken,
}) {
  final token = MapboxTokenService.getTokenSync(override: mapboxToken);

  if (kIsWeb) {
    return MapboxWebCircuitMap(
      mapboxToken: token,
      perimeter: perimeter,
      route: route,
      segments: segments,
      onTapLngLat: onTap,
    );
  }
  if (token.isNotEmpty) {
    // SDK Mapbox natif : token global.
    MapboxOptions.setAccessToken(token);
  }

  return MapboxNativeCircuitMap(
    perimeter: perimeter,
    route: route,
    segments: segments,
    locked: locked,
    showMask: showMask,
    onTapLngLat: onTap,
  );
}
