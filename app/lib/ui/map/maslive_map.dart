import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:convert';

import 'maslive_map_controller.dart';
import 'maslive_poi_style.dart';
import 'maslive_map_native.dart';
import 'maslive_map_web.dart';

/// Extension "Mapbox Pro" pour l'édition POIs via GeoJSON source + layer
///
/// Objectif:
/// - remplace l'affichage POIs en markers/annotations
/// - active le hit-testing (queryRenderedFeatures) sur le layer POI
///
/// ⚠️ Implémentation volontairement isolée ici pour respecter la contrainte
/// "patch en 4 fichiers" (sans toucher à `maslive_map_controller.dart`).
class MasLiveMapControllerPoi extends MasLiveMapController {
  /// Impl interne branchée par `MasLiveMapNative`/`MasLiveMapWeb`.
  Future<void> Function(String featureCollectionJson)? _setPoisGeoJsonImpl;

  /// Impl interne branchée par `MasLiveMapNative`/`MasLiveMapWeb`.
  Future<void> Function(MasLivePoiStyle style)? _setPoiStyleImpl;

  MasLivePoiStyle _poiStyle = const MasLivePoiStyle();

  MasLivePoiStyle get poiStyle => _poiStyle;

  /// Callback POI: tap sur un POI rendu par le layer GeoJSON.
  void Function(String poiId)? onPoiTap;

  /// Callback map: tap sur la carte hors POI.
  void Function(double lat, double lng)? onMapTap;

  /// @nodoc - usage interne seulement
  set setPoisGeoJsonImpl(Future<void> Function(String featureCollectionJson)? impl) {
    _setPoisGeoJsonImpl = impl;
  }

  /// @nodoc - usage interne seulement
  set setPoiStyleImpl(Future<void> Function(MasLivePoiStyle style)? impl) {
    _setPoiStyleImpl = impl;
  }

  /// Met à jour le style des POIs (taille/couleurs).
  ///
  /// Si appelé avant que la carte ne soit prête, le style sera appliqué
  /// lors du prochain rendu (ou dès que possible selon la plateforme).
  Future<void> setPoiStyle(MasLivePoiStyle style) async {
    _poiStyle = style;
    await _setPoiStyleImpl?.call(style);
  }

  /// Met à jour les POIs via un FeatureCollection GeoJSON.
  ///
  /// Contrat:
  /// - Feature.id == poiId
  /// - properties: { poiId, layerId, title }
  Future<void> setPoisGeoJson(Map<String, dynamic> featureCollection) async {
    final json = jsonEncode(featureCollection);
    await _setPoisGeoJsonImpl?.call(json);
  }

  /// Supprime la source/layer POIs.
  Future<void> clearPoisGeoJson() async {
    await _setPoisGeoJsonImpl?.call(_emptyFeatureCollectionJson);
  }

  static const String _emptyFeatureCollectionJson =
      '{"type":"FeatureCollection","features":[]}';
}

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
