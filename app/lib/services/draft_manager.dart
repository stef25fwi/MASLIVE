import 'package:flutter/foundation.dart' show debugPrint;

/// Local draft cache pour brouillons de circuits/routes
class DraftManager {
  /// Sauvegarde un brouillon de circuit (données sérialisées)
  static Future<void> saveCircuitDraft({
    required String? groupId,
    required String? title,
    required String? description,
    required List<Map<String, double>> points,
  }) async {
    final data = {
      'title': title,
      'description': description,
      'points': points,
      'savedAt': DateTime.now().toIso8601String(),
    };
    // En vrai, il faudrait Hive/SharedPrefs ici
    // Pour la démo: on affiche juste dans les logs
    debugPrint('💾 Draft circuit sauvegardé: $data');
  }

  /// Charge un brouillon de circuit
  static Future<Map<String, dynamic>?> loadCircuitDraft({
    required String? groupId,
  }) async {
    // Retourner null si absent
    debugPrint('📂 Chargement brouillon circuit ${groupId ?? "global"}...');
    return null;
  }

  /// Supprime un brouillon
  static Future<void> clearCircuitDraft({required String? groupId}) async {
    debugPrint('🗑️ Brouillon circuit effacé: ${groupId ?? "global"}');
  }

  /// Idem pour routes
  static Future<void> saveRouteDraft({
    required String? groupId,
    required String? name,
    required String? description,
    required List<Map<String, double>> points,
  }) async {
    final data = {
      'name': name,
      'description': description,
      'points': points,
      'savedAt': DateTime.now().toIso8601String(),
    };
    debugPrint('💾 Draft route sauvegardé: $data');
  }

  static Future<Map<String, dynamic>?> loadRouteDraft({
    required String? groupId,
  }) async {
    debugPrint('📂 Chargement brouillon route ${groupId ?? "global"}...');
    return null;
  }

  static Future<void> clearRouteDraft({required String? groupId}) async {
    debugPrint('🗑️ Brouillon route effacé: ${groupId ?? "global"}');
  }
}
