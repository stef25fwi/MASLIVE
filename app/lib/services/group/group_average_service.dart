// Service de calcul et stream de la position moyenne
// Agrège les positions de tous les membres d'un groupe

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_admin.dart';

class GroupAverageService {
  static final GroupAverageService instance = GroupAverageService._();
  GroupAverageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream de la position moyenne (depuis Firestore, calculée par Cloud Function ou client)
  Stream<GeoPosition?> streamAveragePosition(String adminGroupId) {
    return _firestore
        .collection('group_admins')
        .where('adminGroupId', isEqualTo: adminGroupId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final admin = GroupAdmin.fromFirestore(snapshot.docs.first);
      return admin.averagePosition;
    });
  }

  // Calcul client de la position moyenne (fallback si pas de Cloud Function)
  Future<GeoPosition?> calculateAveragePositionClient(String adminGroupId) async {
    // Récupère toutes les positions des membres
    final snapshot = await _firestore
        .collection('group_positions')
        .doc(adminGroupId)
        .collection('members')
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final validPositions = <GeoPosition>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['lastPosition'] != null) {
        final pos = GeoPosition.fromMap(data['lastPosition']);
        // Filtre positions invalides (> 20s, accuracy > 50m)
        if (pos.isValidForAverage()) {
          validPositions.add(pos);
        }
      }
    }

    if (validPositions.isEmpty) {
      return null;
    }

    // Calcule la moyenne
    double sumLat = 0.0;
    double sumLng = 0.0;
    double sumAlt = 0.0;
    int altCount = 0;

    for (final pos in validPositions) {
      sumLat += pos.lat;
      sumLng += pos.lng;
      if (pos.altitude != null) {
        sumAlt += pos.altitude!;
        altCount++;
      }
    }

    final avgLat = sumLat / validPositions.length;
    final avgLng = sumLng / validPositions.length;
    final avgAlt = altCount > 0 ? sumAlt / altCount : null;

    return GeoPosition(
      lat: avgLat,
      lng: avgLng,
      altitude: avgAlt,
      accuracy: null, // Pas de accuracy pour une moyenne
      timestamp: DateTime.now(),
    );
  }

  // Met à jour la position moyenne dans le profil admin (appelé côté client si pas de CF)
  Future<void> updateAveragePositionInAdmin(
    String adminGroupId,
    GeoPosition averagePosition,
  ) async {
    // Trouve l'admin par son adminGroupId
    final adminSnapshot = await _firestore
        .collection('group_admins')
        .where('adminGroupId', isEqualTo: adminGroupId)
        .limit(1)
        .get();

    if (adminSnapshot.docs.isEmpty) {
      return;
    }

    final adminDoc = adminSnapshot.docs.first;
    await adminDoc.reference.update({
      'averagePosition': averagePosition.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream combiné de toutes les positions des membres (pour calcul client temps réel)
  Stream<Map<String, GeoPosition>> streamAllMemberPositions(String adminGroupId) {
    return _firestore
        .collection('group_positions')
        .doc(adminGroupId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      final positions = <String, GeoPosition>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['lastPosition'] != null) {
          final pos = GeoPosition.fromMap(data['lastPosition']);
          if (pos.isValidForAverage()) {
            positions[doc.id] = pos;
          }
        }
      }
      
      return positions;
    });
  }

  // Calcule et met à jour en continu (client-side fallback)
  StreamSubscription<Map<String, GeoPosition>>? _averageSubscription;

  void startClientSideAverageCalculation(String adminGroupId) {
    _averageSubscription?.cancel();

    _averageSubscription = streamAllMemberPositions(adminGroupId).listen(
      (positions) async {
        if (positions.isEmpty) return;

        double sumLat = 0.0;
        double sumLng = 0.0;
        double sumAlt = 0.0;
        int altCount = 0;

        for (final pos in positions.values) {
          sumLat += pos.lat;
          sumLng += pos.lng;
          if (pos.altitude != null) {
            sumAlt += pos.altitude!;
            altCount++;
          }
        }

        final avgPos = GeoPosition(
          lat: sumLat / positions.length,
          lng: sumLng / positions.length,
          altitude: altCount > 0 ? sumAlt / altCount : null,
          timestamp: DateTime.now(),
        );

        await updateAveragePositionInAdmin(adminGroupId, avgPos);
      },
    );
  }

  void stopClientSideAverageCalculation() {
    _averageSubscription?.cancel();
    _averageSubscription = null;
  }
}
