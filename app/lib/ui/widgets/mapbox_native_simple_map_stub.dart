import 'package:flutter/material.dart';

/// Stub pour compilation Web - MapboxNativeSimpleMap n'est pas supporté sur Web
class MapboxNativeSimpleMap extends StatelessWidget {
  const MapboxNativeSimpleMap({
    super.key,
    required this.accessToken,
    this.styleUri = 'mapbox://styles/mapbox/streets-v11',
    this.initialLat = 16.241,
    this.initialLng = -61.534,
    this.initialZoom = 11.5,
    this.onTapLngLat,
  });

  final String accessToken;
  final String styleUri;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final ValueChanged<({double lng, double lat})>? onTapLngLat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Mapbox natif non supporté sur Web.'),
    );
  }
}
