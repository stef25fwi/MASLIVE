import 'package:flutter/material.dart';

import 'maslive_map_controller.dart';

/// Stub non-Web pour éviter d'importer `dart:html`/`dart:js` dans les tests VM.
///
/// Ne doit jamais être utilisé en runtime car `MasLiveMap` ne construit
/// `MasLiveMapWeb` que lorsque `kIsWeb == true`.
class MasLiveMapWeb extends StatelessWidget {
  const MasLiveMapWeb({
    super.key,
    this.controller,
    required this.initialLng,
    required this.initialLat,
    required this.initialZoom,
    this.initialPitch = 0.0,
    this.initialBearing = 0.0,
    this.styleUrl,
    this.showUserLocation = false,
    this.userLng,
    this.userLat,
    this.onTap,
    this.onMapReady,
  });

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
  final void Function(MasLiveMapController)? onMapReady;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
