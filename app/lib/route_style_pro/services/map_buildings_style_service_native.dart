import 'dart:async';
import 'package:flutter/foundation.dart';

import 'map_buildings_style_service.dart';

/// Implémentation native du service de style des bâtiments 3D.
///
/// Cette implémentation utilise directement le SDK Mapbox Maps Flutter pour
/// contrôler les couches fill-extrusion.
///
/// TODO: Intégrer avec votre instance MapboxMap existante.
/// Pour l'instant, cette classe fournit une structure prête à intégrer.
class MapBuildingsStyleServiceNative extends MapBuildingsStyleService {
  /// Instance de la carte Mapbox (à injecter depuis votre page)
  /// 
  /// Exemple dans votre page:
  /// ```dart
  /// final _buildingsService = MapBuildingsStyleServiceNative();
  /// 
  /// Future<void> _onMapCreated(MapboxMap map) async {
  ///   _buildingsService.setMapInstance(map);
  ///   // ...
  /// }
  /// ```
  dynamic _mapboxMap; // Type: MapboxMap du package mapbox_maps_flutter

  /// Cache de l'ID de la couche trouvée
  String? _cachedLayerId;

  /// Injecte l'instance de la carte Mapbox
  void setMapInstance(dynamic mapboxMap) {
    _mapboxMap = mapboxMap;
    _cachedLayerId = null; // Invalide le cache
    _log('map instance set');
  }

  @override
  Future<bool> setBuildingsOpacity(double opacity) async {
    final clampedOpacity = _clampOpacity(opacity);

    if (_mapboxMap == null) {
      _log('map instance not set');
      return false;
    }

    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) {
        _log('no fill-extrusion layer found in current style');
        return false;
      }

      // TODO: Utilisez l'API Mapbox Maps Flutter pour mettre à jour la propriété
      // Exemple (à adapter selon votre version du SDK):
      // 
      // await _mapboxMap.style.setStyleLayerProperty(
      //   layerId,
      //   'fill-extrusion-opacity',
      //   clampedOpacity,
      // );
      
      _log('apply opacity=$clampedOpacity layer=$layerId (TODO: implement native API call)');
      
      // Pour l'instant, retourne true si la couche existe
      // À remplacer par le vrai appel SDK une fois implémenté
      return true;
    } catch (e) {
      _log('setBuildingsOpacity error: $e');
      return false;
    }
  }

  @override
  Future<double?> getBuildingsOpacity() async {
    if (_mapboxMap == null) return null;

    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) return null;

      // TODO: Récupérer la propriété depuis le style
      // Exemple:
      // final value = await _mapboxMap.style.getStyleLayerProperty(
      //   layerId,
      //   'fill-extrusion-opacity',
      // );
      // return value as double?;

      _log('getBuildingsOpacity layer=$layerId (TODO: implement native API call)');
      return 0.60; // Valeur par défaut temporaire
    } catch (e) {
      _log('getBuildingsOpacity error: $e');
      return null;
    }
  }

  @override
  Future<bool> setBuildingsEnabled(bool enabled) async {
    if (_mapboxMap == null) {
      _log('map instance not set');
      return false;
    }

    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) {
        _log('cannot set buildings enabled: layer not found');
        return false;
      }

      // TODO: Changer la visibilité de la couche
      // Exemple:
      // await _mapboxMap.style.setStyleLayerProperty(
      //   layerId,
      //   'visibility',
      //   enabled ? 'visible' : 'none',
      // );

      _log('set buildings enabled=$enabled layer=$layerId (TODO: implement native API call)');
      return true;
    } catch (e) {
      _log('setBuildingsEnabled error: $e');
      return false;
    }
  }

  @override
  Future<bool> is3DBuildingsAvailable() async {
    final layerId = await findBuildingLayer();
    return layerId != null;
  }

  @override
  Future<String?> findBuildingLayer() async {
    // Si on a déjà trouvé une couche, la retourner (cache)
    if (_cachedLayerId != null) {
      return _cachedLayerId;
    }

    if (_mapboxMap == null) {
      _log('map instance not set');
      return null;
    }

    try {
      // TODO: Parcourir les couches du style pour trouver une fill-extrusion
      // Exemple:
      // final layers = await _mapboxMap.style.getStyleLayers();
      // for (final layerId in MapBuildingsStyleService.possibleLayerIds) {
      //   final layer = layers.firstWhere(
      //     (l) => l.id == layerId && l.type == 'fill-extrusion',
      //     orElse: () => null,
      //   );
      //   if (layer != null) {
      //     _cachedLayerId = layer.id;
      //     _log('layer found: ${layer.id}');
      //     return _cachedLayerId;
      //   }
      // }

      // Pour l'instant, retourne le layer ID standard
      const standardLayerId = 'maslive-3d-buildings';
      _cachedLayerId = standardLayerId;
      _log('layer found (hardcoded): $standardLayerId (TODO: implement real layer search)');
      return _cachedLayerId;
    } catch (e) {
      _log('findBuildingLayer error: $e');
      return null;
    }
  }

  /// Invalide le cache de la couche (à appeler après changement de style)
  void invalidateCache() {
    _cachedLayerId = null;
    _log('cache invalidated');
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[BuildingsOpacity] $message');
    }
  }

  double _clampOpacity(double value) {
    return value.clamp(0.0, 1.0);
  }
}
