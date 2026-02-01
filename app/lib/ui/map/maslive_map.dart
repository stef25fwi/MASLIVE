import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'maslive_map_controller.dart';
import 'maslive_map_native.dart';
import 'maslive_map_web.dart';

/// Widget de carte unifié pour toute l'application MASLIVE
///
/// Phase 1: Mapbox unique (Web + Natif) avec API complète
///
/// Utilise automatiquement :
/// - MapboxWebView (web) via Mapbox GL JS
/// - MapWidget natif (iOS/Android) via mapbox_maps_flutter
///
/// Usage :
/// ```dart
/// final controller = MasLiveMapController();
///
/// MasLiveMap(
///   controller: controller,
///   initialLng: -61.533,
///   initialLat: 16.241,
///   initialZoom: 15.0,
///   onMapReady: (controller) async {
///     await controller.setUserLocation(lng: -61.533, lat: 16.241);
///     await controller.setMarkers([
///       MapMarker(id: '1', lng: -61.533, lat: 16.241, label: 'Start'),
///     ]);
///   },
/// )
/// ```
class MasLiveMap extends StatelessWidget {
  final MasLiveMapController? controller;
  final double initialLng;
  final double initialLat;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final String? styleUrl;
  final bool showUserLocation;
  final double? userLng;
  final double? userLat;
  final ValueChanged<MapPoint>? onTap;
  final void Function(MasLiveMapController controller)? onMapReady;

  const MasLiveMap({
    super.key,
    this.controller,
    this.initialLng = -61.5340,
    this.initialLat = 16.2410,
    this.initialZoom = 15.0,
    this.initialPitch = 0.0,
    this.initialBearing = 0.0,
    this.styleUrl,
    this.showUserLocation = false,
    this.userLng,
    this.userLat,
    this.onTap,
    this.onMapReady,
  });

  @override
  Widget build(BuildContext context) {
    // Choisir l'implémentation selon la plateforme
    if (kIsWeb) {
      return MasLiveMapWeb(
        controller: controller,
        initialLng: initialLng,
        initialLat: initialLat,
        initialZoom: initialZoom,
        initialPitch: initialPitch,
        initialBearing: initialBearing,
        styleUrl: styleUrl,
        showUserLocation: showUserLocation,
        userLng: userLng,
        userLat: userLat,
        onTap: onTap,
        onMapReady: onMapReady,
      );
    } else {
      return MasLiveMapNative(
        controller: controller,
        initialLng: initialLng,
        initialLat: initialLat,
        initialZoom: initialZoom,
        initialPitch: initialPitch,
        initialBearing: initialBearing,
        styleUrl: styleUrl,
        showUserLocation: showUserLocation,
        userLng: userLng,
        userLat: userLat,
        onTap: onTap,
        onMapReady: onMapReady,
      );
    }
  }
}
