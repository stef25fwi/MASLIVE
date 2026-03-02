import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'map_buildings_style_service.dart';

/// Implémentation **native** (iOS/Android) du contrôle des bâtiments 3D.
///
/// Cette classe avait été coupée/corrompue pendant une édition : on la remet
/// en état avec une implémentation fonctionnelle basée sur `setStyleLayerProperty`.
///
/// Usage:
/// ```dart
/// final buildings = MapBuildingsStyleServiceNative();
///
/// void _onMapCreated(MapboxMap map) {
///   buildings.setMapInstance(map);
/// }
/// ```
class MapBuildingsStyleServiceNative extends MapBuildingsStyleService {
  MapboxMap? _mapboxMap;

  String? _cachedLayerId;
  double? _lastAppliedOpacity;
  bool? _lastAppliedEnabled;

  /// Injecte l'instance de la carte Mapbox.
  void setMapInstance(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    invalidateCache();
    _log('map instance set');
  }

  @override
  Future<bool> setBuildingsOpacity(double opacity) async {
    final map = _mapboxMap;
    if (map == null) {
      _log('map instance not set');
      return false;
    }

    final clampedOpacity = _clampOpacity(opacity);
    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) {
        _log('no fill-extrusion layer found in current style');
        return false;
      }

      await map.style.setStyleLayerProperty(
        layerId,
        'fill-extrusion-opacity',
        clampedOpacity,
      );

      _lastAppliedOpacity = clampedOpacity;
      _log('apply opacity=$clampedOpacity layer=$layerId success');
      return true;
    } catch (e) {
      _log('setBuildingsOpacity error: $e');
      return false;
    }
  }

  @override
  Future<double?> getBuildingsOpacity() async {
    final map = _mapboxMap;
    if (map == null) {
      _log('map instance not set');
      return null;
    }

    // Best effort: si on a déjà appliqué une valeur, on la renvoie.
    final cached = _lastAppliedOpacity;
    if (cached != null) return cached;

    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) return null;

      // Selon versions du SDK, `getStyleLayerProperty` peut exister.
      // On passe via `dynamic` pour ne pas bloquer la compilation.
      final dynamic style = map.style;
      final dynamic raw = await style.getStyleLayerProperty(
        layerId,
        'fill-extrusion-opacity',
      );

      final parsed = _tryParseNumFromStyleProperty(raw);
      if (parsed != null) {
        _lastAppliedOpacity = _clampOpacity(parsed);
        return _lastAppliedOpacity;
      }
    } catch (e) {
      _log('getBuildingsOpacity error: $e');
    }

    return null;
  }

  @override
  Future<bool> setBuildingsEnabled(bool enabled) async {
    final map = _mapboxMap;
    if (map == null) {
      _log('map instance not set');
      return false;
    }

    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) {
        _log('cannot set buildings enabled: layer not found');
        return false;
      }

      await map.style.setStyleLayerProperty(
        layerId,
        'visibility',
        enabled ? 'visible' : 'none',
      );

      _lastAppliedEnabled = enabled;
      _log('apply visibility=${enabled ? 'visible' : 'none'} layer=$layerId success');
      return true;
    } catch (e) {
      _log('setBuildingsEnabled error: $e');
      return false;
    }
  }

  @override
  Future<bool> is3DBuildingsAvailable() async {
    return (await findBuildingLayer()) != null;
  }

  @override
  Future<String?> findBuildingLayer() async {
    if (_cachedLayerId != null) return _cachedLayerId;
    final map = _mapboxMap;
    if (map == null) {
      _log('map instance not set');
      return null;
    }

    // Stratégie: tenter les IDs connus en lisant une propriété (si supportée).
    // Sinon, fallback: tester l'existence via un setStyleLayerProperty "réversible"
    // (on ne modifie rien si la couche n'existe pas, l'appel lève).
    for (final id in MapBuildingsStyleService.possibleLayerIds) {
      if (id.trim().isEmpty) continue;
      if (await _styleLayerSeemsToExist(map, id)) {
        _cachedLayerId = id;
        _log('layer found: $id');
        return id;
      }
    }

    _log('no fill-extrusion layer found in current style');
    return null;
  }

  /// Invalide le cache (à appeler après un changement de style).
  void invalidateCache() {
    _cachedLayerId = null;
  }

  Future<bool> _styleLayerSeemsToExist(MapboxMap map, String layerId) async {
    // 1) Tentative via getStyleLayerProperty (si dispo dans cette version).
    try {
      final dynamic style = map.style;
      final dynamic v = await style.getStyleLayerProperty(layerId, 'visibility');
      // Si ça ne jette pas, c'est déjà un bon signal.
      if (v != null) return true;
    } catch (_) {
      // ignore
    }

    // 2) Fallback: essayer d'écrire une propriété inoffensive.
    // Si la couche n'existe pas, Mapbox lève une erreur.
    try {
      final desired = _lastAppliedEnabled == false ? 'none' : 'visible';
      await map.style.setStyleLayerProperty(layerId, 'visibility', desired);
      return true;
    } catch (_) {
      return false;
    }
  }

  double? _tryParseNumFromStyleProperty(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();

    // Certains retours platform sont de la forme {"value": ...}
    if (raw is Map) {
      final v = raw['value'];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    }

    // D'autres renvoient un objet avec champ `.value`.
    try {
      final dynamic v = raw.value;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {
      // ignore
    }

    return null;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[BuildingsOpacity][native] $message');
    }
  }

  double _clampOpacity(double value) => value.clamp(0.0, 1.0);
}
