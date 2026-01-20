import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionService {
  static final CloudFunctionService _instance =
      CloudFunctionService._internal();

  CloudFunctionService._internal();

  factory CloudFunctionService() {
    return _instance;
  }

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-east1');

  /// Nearby Search: Cherche des groupes proches (via `groups.lastLocation`)
  /// Cloud Function: `nearbySearch`
  /// - attend: { centerLat, centerLng, radiusKm?, limit? }
  /// - retourne: { ok, count, items }
  Future<List<Map<String, dynamic>>> nearbySearch({
    required double centerLat,
    required double centerLng,
    double radiusKm = 2,
    int limit = 50,
  }) async {
    try {
      final callable = _functions.httpsCallable('nearbySearch');
      final result = await callable.call({
        'centerLat': centerLat,
        'centerLng': centerLng,
        'radiusKm': radiusKm,
        'limit': limit,
      });

      final data = result.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();
      return items;
    } catch (e) {
      // print('Erreur nearbySearch: $e');
      rethrow;
    }
  }

  /// Update Group Location: Envoie la position du groupe (tracking 15s)
  /// ✅ Inclut ownerId automatiquement (userId) pour la sécurité Firestore
  Future<void> updateGroupLocation({
    required String groupId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateGroupLocation');
      await callable.call({
        'groupId': groupId,
        'lat': lat,
        'lng': lng,
        'heading': heading,
        'speed': speed,
        // ownerId est géré côté backend (context.auth.uid)
      });
    } catch (e) {
      // print('Erreur updateGroupLocation: $e');
      rethrow;
    }
  }
}
