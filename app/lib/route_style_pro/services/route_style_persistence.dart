import 'dart:convert';
import 'dart:ui' show Color;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/route_style_config.dart';

class RouteStylePersistence {
  static const String _prefsKey = 'maslive.routeStylePro';

  Future<RouteStyleConfig?> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return RouteStyleConfig.fromJson(decoded);
  }

  Future<void> saveLocal(RouteStyleConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Charge depuis Firestore, si un contexte est fourni.
  ///
  /// - Si [projectId] : map_projects/{projectId}.routeStylePro
  /// - Si [circuitId] : circuits/{circuitId}/style/routeStyle
  Future<RouteStyleConfig?> loadRemote({
    String? projectId,
    String? circuitId,
  }) async {
    if ((projectId ?? '').trim().isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .get();
      final data = doc.data();
      final raw = data?['routeStylePro'];
      if (raw is Map) {
        return RouteStyleConfig.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    }

    if ((circuitId ?? '').trim().isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('circuits')
          .doc(circuitId)
          .collection('style')
          .doc('routeStyle')
          .get();
      final raw = doc.data();
      if (raw != null) {
        return RouteStyleConfig.fromJson(raw);
      }
      return null;
    }

    return null;
  }

  /// Sauvegarde vers Firestore (optionnel) + une projection minimaliste dans
  /// `routeStyle` (compat avec l'éditeur existant) quand [projectId] est fourni.
  Future<void> saveRemote(
    RouteStyleConfig config, {
    String? projectId,
    String? circuitId,
  }) async {
    if ((projectId ?? '').trim().isNotEmpty) {
      final doc = FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId);

      // C7: compat partielle avec l'ancienne UI (wizard circuit).
      // On sauvegarde `routeStylePro` complet, et on produit une projection
      // `routeStyle` minimaliste *en préservant* les champs legacy existants.
      //
      // Important: selon les clients/SDK, un set(merge:true) peut quand même
      // remplacer le map `routeStyle` au lieu de faire une fusion profonde.
      // Pour éviter toute perte de clés legacy, on repart du `routeStyle`
      // existant et on ne surchage que ce qui est nécessaire.
      final existingSnap = await doc.get();
      final existingData = existingSnap.data();
      final existingRouteStyleRaw = existingData?['routeStyle'];
      final existingCurrentRaw = existingData?['current'];

      final mergedLegacy = <String, dynamic>{};
      if (existingRouteStyleRaw is Map) {
        mergedLegacy.addAll(Map<String, dynamic>.from(existingRouteStyleRaw));
      }

      final preservedRoadLike = (mergedLegacy['roadLike'] is bool)
          ? mergedLegacy['roadLike'] as bool
          : true;
      final preservedShowDirection = (mergedLegacy['showDirection'] is bool)
          ? mergedLegacy['showDirection'] as bool
          : true;

      mergedLegacy['roadLike'] = preservedRoadLike;
      mergedLegacy['showDirection'] = preservedShowDirection;
      mergedLegacy['color'] = _toHexRgb(config.mainColor);
      mergedLegacy['width'] = config.mainWidth;
      mergedLegacy['shadow3d'] = config.shadowEnabled;
      mergedLegacy['animateDirection'] = config.pulseEnabled;
      mergedLegacy['animationSpeed'] =
          (config.pulseSpeed / 25.0).clamp(0.5, 5.0);

      final payload = <String, dynamic>{
        'routeStylePro': config.toJson(),
        // Compat “ancienne UI”: un sous-ensemble exploitable immédiatement.
        'routeStyle': mergedLegacy,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Canon writer: si `current` existe déjà, on maintient aussi la sync dans `current.*`.
      // (Ne pas créer `current` ici: il a une shape stricte côté rules.)
      if (existingCurrentRaw is Map) {
        payload['current'] = {
          'routeStyle': mergedLegacy,
          'routeStylePro': config.toJson(),
        };
      }

      await doc.set(payload, SetOptions(merge: true));
      return;
    }

    if ((circuitId ?? '').trim().isNotEmpty) {
      final doc = FirebaseFirestore.instance
          .collection('circuits')
          .doc(circuitId)
          .collection('style')
          .doc('routeStyle');
      await doc.set(config.toJson(), SetOptions(merge: true));
      return;
    }
  }

  String _toHexRgb(Color c) {
    final r = ((c.r * 255).round()).clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = ((c.g * 255).round()).clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = ((c.b * 255).round()).clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }
}
