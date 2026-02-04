// Service de calcul et stream de la position moyenne
// Agrège les positions de tous les membres d'un groupe
// Utilise calcul géodésique pour précision sur longues distances
// Pondération par accuracy pour meilleures positions

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_admin.dart';
import '../../utils/geo_utils.dart';

class GroupAverageService {
  static final GroupAverageService instance = GroupAverageService._();
  GroupAverageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Mode calcul: 'arithmetic' (rapide, local), 'geodetic' (précis, distance)
  String _calculationMode = 'geodetic'; // Défaut: géodésique pour meilleure précision

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
  // Utilise géodésique + pondération par accuracy
  Future<GeoPosition?> calculateAveragePositionClient(
    String adminGroupId, {
    bool useWeightedAverage = true,
    bool useGeodetic = true,
  }) async {
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

    // Calcule les poids basés sur accuracy (plus petit = plus fiable)
    final weights = useWeightedAverage
        ? _calculateWeights(validPositions)
        : List.filled(validPositions.length, 1.0);

    late final GeoPosition avgPos;

    if (useGeodetic) {
      // Utilise calcul géodésique (plus précis)
      final positions = validPositions
          .map((p) => (latitude: p.lat, longitude: p.lng, altitude: p.altitude ?? 0.0))
          .toList();

      final result = GeoUtils.calculateGeodeticCenter(positions, useWeights: useWeightedAverage, weights: weights);

      avgPos = GeoPosition(
        lat: result.latitude,
        lng: result.longitude,
        altitude: result.altitude,
        accuracy: null,
        timestamp: DateTime.now(),
      );
    } else {
      // Utilise moyenne arithmétique (rapide, local)
      double sumLat = 0.0;
      double sumLng = 0.0;
      double sumAlt = 0.0;
      int altCount = 0;
      double sumWeights = 0.0;

      for (int i = 0; i < validPositions.length; i++) {
        final pos = validPositions[i];
        final weight = weights[i];

        sumLat += pos.lat * weight;
        sumLng += pos.lng * weight;
        sumWeights += weight;

        if (pos.altitude != null) {
          sumAlt += pos.altitude! * weight;
          altCount++;
        }
      }

      final avgLat = sumLat / sumWeights;
      final avgLng = sumLng / sumWeights;
      final avgAlt = altCount > 0 ? sumAlt / altCount : null;

      avgPos = GeoPosition(
        lat: avgLat,
        lng: avgLng,
        altitude: avgAlt,
        accuracy: null,
        timestamp: DateTime.now(),
      );
    }

    return avgPos;
  }

  /// Calcule les poids inversement proportionnels à l'accuracy
  /// Positions avec faible accuracy = poids élevé
  List<double> _calculateWeights(List<GeoPosition> positions) {
    const double maxAccuracy = 50.0; // Accuracy max en mètres
    
    return positions.map((pos) {
      final accuracy = pos.accuracy ?? maxAccuracy;
      // Poids = 1 / (1 + accuracy)
      // accuracy=0 → poids=1.0 (excellent)
      // accuracy=50 → poids=0.02 (bon)
      return 1.0 / (1.0 + accuracy / maxAccuracy);
    }).toList();
  }

  /// Change le mode de calcul
  void setCalculationMode(String mode) {
    if (['arithmetic', 'geodetic'].contains(mode)) {
      _calculationMode = mode;
    }
  }

  /// Récupère le mode de calcul actuel
  String getCalculationMode() => _calculationMode;

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
