/// Local draft cache pour brouillons de circuits/routes
class DraftManager {
  static const _prefix = 'draft_';

  static String _keyCircuit(String? groupId) =>
      '${_prefix}circuit_${groupId ?? "global"}';
  static String _keyRoute(String? groupId) =>
      '${_prefix}route_${groupId ?? "global"}';

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
    print('💾 Draft circuit sauvegardé: $data');
  }

  /// Charge un brouillon de circuit
  static Future<Map<String, dynamic>?> loadCircuitDraft({
    required String? groupId,
  }) async {
    // Retourner null si absent
    print('📂 Chargement brouillon circuit ${groupId ?? "global"}...');
    return null;
  }

  /// Supprime un brouillon
  static Future<void> clearCircuitDraft({required String? groupId}) async {
    print('🗑️ Brouillon circuit effacé: ${groupId ?? "global"}');
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
    print('💾 Draft route sauvegardé: $data');
  }

  static Future<Map<String, dynamic>?> loadRouteDraft({
    required String? groupId,
  }) async {
    print('📂 Chargement brouillon route ${groupId ?? "global"}...');
    return null;
  }

  static Future<void> clearRouteDraft({required String? groupId}) async {
    print('🗑️ Brouillon route effacé: ${groupId ?? "global"}');
  }
}
