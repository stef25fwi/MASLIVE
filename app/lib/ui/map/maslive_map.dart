import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:convert';

import 'maslive_map_controller.dart';
import 'maslive_poi_style.dart';
import 'poi_picto_images.dart';
import 'maslive_map_native.dart';
import 'maslive_map_web_stub.dart'
    if (dart.library.html) 'maslive_map_web.dart';

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
  set setPoisGeoJsonImpl(
    Future<void> Function(String featureCollectionJson)? impl,
  ) {
    _setPoisGeoJsonImpl = impl;
  }

  /// @nodoc - usage interne seulement
  set setPoiStyleImpl(Future<void> Function(MasLivePoiStyle style)? impl) {
    _setPoiStyleImpl = impl;
  }

  /// Impl interne branchée par `MasLiveMapNative`/`MasLiveMapWeb` pour
  /// enregistrer les images de pictos POI sur la carte.
  Future<void> Function(List<PoiPictoImage> images)? _registerPoiPictoImagesImpl;

  List<PoiPictoImage> _poiPictoImages = const [];

  /// Dernières images de pictos fournies (ré-enregistrées après un changement
  /// de style qui efface les images runtime).
  List<PoiPictoImage> get poiPictoImages => _poiPictoImages;

  /// @nodoc - usage interne seulement
  set registerPoiPictoImagesImpl(
    Future<void> Function(List<PoiPictoImage> images)? impl,
  ) {
    _registerPoiPictoImagesImpl = impl;
  }

  /// Enregistre les images de pictos POI (marqueurs) sur la carte.
  ///
  /// À appeler une fois la carte prête. Sans effet si aucune impl n'est
  /// branchée (le POI retombe alors sur son rendu par cercle).
  Future<void> registerPoiPictoImages(List<PoiPictoImage> images) async {
    _poiPictoImages = images;
    await _registerPoiPictoImagesImpl?.call(images);
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

  /// Web (Mapbox GL JS): contrôle le mode compact de l'attribution.
  ///
  /// - `true` (défaut): comportement Mapbox standard (bouton compact "i" selon viewport).
  /// - `false`: supprime le bouton compact et force l'affichage non-compact.
  final bool compactAttribution;
  final bool forceCompactAttribution;
  final bool showAttributionControl;
  final bool showMapboxLogo;
  final bool prioritizeFirstFrame;
  final String controlsPosition;
  final ValueChanged<MapPoint>? onTap;
  final void Function(MasLiveMapController controller)? onMapReady;
  final void Function(String message)? onInitError;
  final void Function()? onStyleFallback;

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
    this.compactAttribution = true,
    this.forceCompactAttribution = false,
    this.showAttributionControl = true,
    this.showMapboxLogo = true,
    this.prioritizeFirstFrame = false,
    this.controlsPosition = 'top-right',
    this.onTap,
    this.onMapReady,
    this.onInitError,
    this.onStyleFallback,
  });

  ValueChanged<MapPoint>? _guardMapTap(BuildContext context) {
    final callback = onTap;
    if (callback == null) return null;

    return (point) {
      final route = ModalRoute.of(context);

      // Une boîte de dialogue, une bottom sheet ou une autre route est ouverte
      // au-dessus de la carte. Le clic ne doit jamais traverser jusqu'à Mapbox.
      if (route != null && !route.isCurrent) return;

      callback(point);
    };
  }

  @override
  Widget build(BuildContext context) {
    final guardedOnTap = _guardMapTap(context);

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
        compactAttribution: compactAttribution,
        forceCompactAttribution: forceCompactAttribution,
        showAttributionControl: showAttributionControl,
        showMapboxLogo: showMapboxLogo,
        prioritizeFirstFrame: prioritizeFirstFrame,
        controlsPosition: controlsPosition,
        onTap: guardedOnTap,
        onMapReady: onMapReady,
        onInitError: onInitError,
        onStyleFallback: onStyleFallback,
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
        onTap: guardedOnTap,
        onMapReady: onMapReady,
        onInitError: onInitError,
        onStyleFallback: onStyleFallback,
      );
    }
  }
}
