/// Service pour gérer la visibilité du groupe sur les cartes
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMapVisibilityService {
  static final GroupMapVisibilityService instance = GroupMapVisibilityService._();
  GroupMapVisibilityService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ajoute une carte à la liste des cartes visibles du groupe
  Future<void> addMapVisibility({
    required String adminUid,
    required String mapId,
    required String mapName,
  }) async {
    try {
      await _firestore.collection('group_admins').doc(adminUid).update({
        'visibleMapIds': FieldValue.arrayUnion([mapId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erreur ajout visibilité carte: $e');
      rethrow;
    }
  }

  /// Retire une carte de la liste des cartes visibles
  Future<void> removeMapVisibility({
    required String adminUid,
    required String mapId,
  }) async {
    try {
      await _firestore.collection('group_admins').doc(adminUid).update({
        'visibleMapIds': FieldValue.arrayRemove([mapId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erreur suppression visibilité carte: $e');
      rethrow;
    }
  }

  /// Bascule la visibilité d'une carte
  Future<void> toggleMapVisibility({
    required String adminUid,
    required String mapId,
    required bool isVisible,
  }) async {
    if (isVisible) {
      await addMapVisibility(
        adminUid: adminUid,
        mapId: mapId,
        mapName: '', // Non utilisé ici
      );
    } else {
      await removeMapVisibility(
        adminUid: adminUid,
        mapId: mapId,
      );
    }
  }

  /// Récupère les cartes visibles du groupe
  Future<List<String>> getVisibleMaps(String adminUid) async {
    try {
      final doc = await _firestore.collection('group_admins').doc(adminUid).get();
      if (!doc.exists) return [];
      
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['visibleMapIds'] ?? []);
    } catch (e) {
      print('❌ Erreur récupération cartes visibles: $e');
      return [];
    }
  }

  /// Stream des cartes visibles
  Stream<List<String>> streamVisibleMaps(String adminUid) {
    return _firestore
        .collection('group_admins')
        .doc(adminUid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['visibleMapIds'] ?? []);
    });
  }

  /// Vérifie si un groupe est visible sur une carte spécifique
  Stream<bool> isGroupVisibleOnMap({
    required String adminUid,
    required String mapId,
  }) {
    return streamVisibleMaps(adminUid).map((visibleMaps) {
      return visibleMaps.contains(mapId);
    });
  }
}
