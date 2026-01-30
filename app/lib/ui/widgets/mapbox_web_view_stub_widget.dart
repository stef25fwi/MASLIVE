import 'package:flutter/material.dart';

/// Stub safe pour les plateformes non-web.
class MapboxWebView extends StatelessWidget {
  final String accessToken;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final String? styleUrl;
  final double? userLat;
  final double? userLng;
  final bool showUserLocation;
  final ValueChanged<({double lng, double lat})>? onTapLngLat;

  const MapboxWebView({
    super.key,
    required this.accessToken,
    this.initialLat = 16.2410,
    this.initialLng = -61.5340,
    this.initialZoom = 15.0,
    this.initialPitch = 45.0,
    this.initialBearing = 0.0,
    this.styleUrl,
    this.userLat,
    this.userLng,
    this.showUserLocation = false,
    this.onTapLngLat,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
