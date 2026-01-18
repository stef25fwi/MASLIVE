import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionService {
  static final CloudFunctionService _instance =
      CloudFunctionService._internal();

  CloudFunctionService._internal();

  factory CloudFunctionService() {
    return _instance;
  }

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Nearby Search: Cherche les places/groupes proches
  /// [lat], [lng]: coordonnées de recherche
  /// [radiusKm]: rayon en km (défaut 5)
  /// [type]: "place" ou "group_location"
  Future<List<Map<String, dynamic>>> nearbySearch({
    required double lat,
    required double lng,
    double radiusKm = 5,
    String type = 'place',
  }) async {
    try {
      final callable = _functions.httpsCallable('nearbySearch');
      final result = await callable.call({
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        'type': type,
      });

      final data = result.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      return results;
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
