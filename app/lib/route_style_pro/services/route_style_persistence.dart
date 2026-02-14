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

      // Préserve les valeurs existantes pour éviter toute surprise côté wizard Circuit.
      bool preservedRoadLike = true;
      bool preservedShowDirection = true;
      try {
        final existing = await doc.get();
        final data = existing.data();
        final routeStyle = data?['routeStyle'];
        if (routeStyle is Map) {
          final m = Map<String, dynamic>.from(routeStyle);
          final rl = m['roadLike'];
          if (rl is bool) preservedRoadLike = rl;
          final sd = m['showDirection'];
          if (sd is bool) preservedShowDirection = sd;
        }
      } catch (_) {
        // ignore: fallback aux valeurs par défaut
      }

      await doc.set({
        'routeStylePro': config.toJson(),
        // Compat “ancienne UI”: un sous-ensemble exploitable immédiatement.
        'routeStyle': {
          'color': _toHexRgb(config.mainColor),
          'width': config.mainWidth,
          'roadLike': preservedRoadLike,
          'shadow3d': config.shadowEnabled,
          'showDirection': preservedShowDirection,
          'animateDirection': config.pulseEnabled,
          'animationSpeed': (config.pulseSpeed / 25.0).clamp(0.5, 5.0),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
