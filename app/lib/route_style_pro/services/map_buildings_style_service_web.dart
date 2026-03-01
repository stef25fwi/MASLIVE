import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'map_buildings_style_service.dart';

/// Implémentation web du service de style des bâtiments 3D.
///
/// Utilise le bridge JavaScript global `window.mapboxBridge` pour
/// communiquer avec Mapbox GL JS.
class MapBuildingsStyleServiceWeb extends MapBuildingsStyleService {
  /// Cache de l'ID de la couche trouvée
  String? _cachedLayerId;

  /// Cache pour éviter trop d'appels JS
  DateTime? _lastCheckTime;
  bool? _lastAvailability;

  @override
  Future<bool> setBuildingsOpacity(double opacity) async {
    final clampedOpacity = _clampOpacity(opacity);

    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) {
        _log('no fill-extrusion layer found in current style');
        return false;
      }

      // Appel JS: window.mapboxBridge.setBuildingsOpacity(layerId, opacity)
      final result = _callJsFunction('setBuildingsOpacity', [layerId, clampedOpacity]);
      
      if (result == true) {
        _log('apply opacity=$clampedOpacity layer=$layerId success');
        return true;
      } else {
        _log('apply opacity=$clampedOpacity layer=$layerId failed');
        return false;
      }
    } catch (e) {
      _log('setBuildingsOpacity error: $e');
      return false;
    }
  }

  @override
  Future<double?> getBuildingsOpacity() async {
    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) return null;

      // Appel JS: window.mapboxBridge.getBuildingsOpacity(layerId)
      final result = _callJsFunction('getBuildingsOpacity', [layerId]);
      
      if (result is num) {
        return result.toDouble();
      }
      return null;
    } catch (e) {
      _log('getBuildingsOpacity error: $e');
      return null;
    }
  }

  @override
  Future<bool> setBuildingsEnabled(bool enabled) async {
    try {
      final layerId = await findBuildingLayer();
      if (layerId == null) {
        _log('cannot set buildings enabled: layer not found');
        return false;
      }

      // Appel JS: window.mapboxBridge.setBuildingsEnabled(layerId, enabled)
      final result = _callJsFunction('setBuildingsEnabled', [layerId, enabled]);
      
      if (result == true) {
        _log('set buildings enabled=$enabled layer=$layerId success');
        return true;
      } else {
        _log('set buildings enabled=$enabled layer=$layerId failed');
        return false;
      }
    } catch (e) {
      _log('setBuildingsEnabled error: $e');
      return false;
    }
  }

  @override
  Future<bool> is3DBuildingsAvailable() async {
    // Cache pour 5 secondes
    if (_lastCheckTime != null && _lastAvailability != null) {
      if (DateTime.now().difference(_lastCheckTime!) < const Duration(seconds: 5)) {
        return _lastAvailability!;
      }
    }

    final layerId = await findBuildingLayer();
    _lastCheckTime = DateTime.now();
    _lastAvailability = layerId != null;
    
    return _lastAvailability!;
  }

  @override
  Future<String?> findBuildingLayer() async {
    // Si on a déjà trouvé une couche, la retourner (cache)
    if (_cachedLayerId != null) {
      return _cachedLayerId;
    }

    try {
      // Appel JS: window.mapboxBridge.findBuildingLayer()
      final result = _callJsFunction('findBuildingLayer', []);
      
      if (result is String && result.isNotEmpty) {
        _cachedLayerId = result;
        _log('layer found: $result');
        return result;
      }

      _log('no building layer found');
      return null;
    } catch (e) {
      _log('findBuildingLayer error: $e');
      return null;
    }
  }

  /// Invalide le cache de la couche (à appeler après changement de style)
  void invalidateCache() {
    _cachedLayerId = null;
    _lastCheckTime = null;
    _lastAvailability = null;
    _log('cache invalidated');
  }

  /// Appelle une fonction du bridge JavaScript
  ///
  /// Retourne la valeur retournée par JS ou `null` en cas d'erreur.
  dynamic _callJsFunction(String functionName, List<dynamic> args) {
    try {
      // Vérifier que le bridge existe
      final bridge = web.window.getProperty('mapboxBridge'.toJS);
      if (bridge == null) {
        _log('mapboxBridge not found in window');
        return null;
      }

      // Appeler la fonction
      final function = bridge.getProperty(functionName.toJS);
      if (function == null) {
        _log('$functionName not found in mapboxBridge');
        return null;
      }

      // Convertir les arguments en JSAny
      final jsArgs = args.map((arg) {
        if (arg is String) return arg.toJS;
        if (arg is num) return arg.toJS;
        if (arg is bool) return arg.toJS;
        return arg;
      }).toList();

      // Appeler avec apply
      final result = function.callMethod('apply'.toJS, [bridge, jsArgs.toJS].toJS);
      
      // Convertir le résultat
      if (result == null) return null;
      if (result.typeofEquals('boolean')) return (result as JSBoolean).toDart;
      if (result.typeofEquals('number')) return (result as JSNumber).toDartDouble;
      if (result.typeofEquals('string')) return (result as JSString).toDart;
      
      return result;
    } catch (e) {
      _log('_callJsFunction($functionName) error: $e');
      return null;
    }
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
