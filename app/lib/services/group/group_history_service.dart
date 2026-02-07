/// Service pour sauvegarder historique des positions moyennes
/// Crée des snapshots réguliers pour analyser évolution
library;

import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_admin.dart';

class GroupHistoryService {
  static final GroupHistoryService instance = GroupHistoryService._();
  GroupHistoryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Enregistre un snapshot de position moyenne
  /// Automatisé via Cloud Function, mais peut être appelé manuellement
  Future<void> recordAveragePositionSnapshot({
    required String adminGroupId,
    required String adminUid,
    required GeoPosition position,
    required int memberCount,
    Map<String, dynamic>? metadata,
  }) async {
    final snapshot = {
      'adminGroupId': adminGroupId,
      'timestamp': FieldValue.serverTimestamp(),
      'position': {
        'lat': position.lat,
        'lng': position.lng,
        'altitude': position.altitude ?? 0.0,
      },
      'memberCount': memberCount,
      'metadata': metadata ?? {},
    };

    try {
      await _firestore
          .collection('group_admins')
          .doc(adminUid)
          .collection('averagePositionHistory')
          .add(snapshot);
    } catch (e) {
      developer.log(
        'Erreur enregistrement snapshot',
        name: 'GroupHistoryService',
        error: e,
      );
    }
  }

  /// Récupère l'historique des positions moyennes
  Stream<List<Map<String, dynamic>>> streamAveragePositionHistory({
    required String adminUid,
    int limitDays = 7,
  }) {
    final cutoffDate =
        DateTime.now().subtract(Duration(days: limitDays));

    return _firestore
        .collection('group_admins')
        .doc(adminUid)
        .collection('averagePositionHistory')
        .where('timestamp', isGreaterThan: cutoffDate)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  /// Exporte l'historique en CSV
  Future<String> exportHistoryToCsv({
    required String adminUid,
    int limitDays = 7,
  }) async {
    final cutoffDate =
        DateTime.now().subtract(Duration(days: limitDays));

    final snapshot = await _firestore
        .collection('group_admins')
        .doc(adminUid)
        .collection('averagePositionHistory')
        .where('timestamp', isGreaterThan: cutoffDate)
        .orderBy('timestamp')
        .get();

    if (snapshot.docs.isEmpty) {
      return 'timestamp,latitude,longitude,altitude,memberCount\n';
    }

    final buffer = StringBuffer();
    buffer.writeln('timestamp,latitude,longitude,altitude,memberCount');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final ts = (data['timestamp'] as Timestamp).toDate();
      final pos = data['position'] as Map<String, dynamic>;
      final memberCount = data['memberCount'] ?? 0;

      buffer.writeln(
        '${ts.toIso8601String()},${pos['lat']},${pos['lng']},${pos['altitude']},$memberCount',
      );
    }

    return buffer.toString();
  }

  /// Nettoie l'historique (garder seulement N jours)
  Future<void> cleanupOldHistory({
    required String adminUid,
    int keepDays = 30,
  }) async {
    final cutoffDate =
        DateTime.now().subtract(Duration(days: keepDays));

    final snapshot = await _firestore
        .collection('group_admins')
        .doc(adminUid)
        .collection('averagePositionHistory')
        .where('timestamp', isLessThan: cutoffDate)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    developer.log(
      'Nettoyage historique: ${snapshot.docs.length} documents supprimés',
      name: 'GroupHistoryService',
    );
  }

  /// Récupère statistiques de l'historique
  Future<Map<String, dynamic>> getHistoryStats({
    required String adminUid,
    int limitDays = 7,
  }) async {
    final cutoffDate =
        DateTime.now().subtract(Duration(days: limitDays));

    final snapshot = await _firestore
        .collection('group_admins')
        .doc(adminUid)
        .collection('averagePositionHistory')
        .where('timestamp', isGreaterThan: cutoffDate)
        .get();

    if (snapshot.docs.isEmpty) {
      return {
        'count': 0,
        'firstSnapshot': null,
        'lastSnapshot': null,
        'avgMemberCount': 0,
      };
    }

    final docs = snapshot.docs.map((d) => d.data()).toList();
    final memberCounts = docs
        .map((d) => (d['memberCount'] as num).toInt())
        .toList();

    return {
      'count': docs.length,
      'firstSnapshot': (docs.first['timestamp'] as Timestamp).toDate(),
      'lastSnapshot': (docs.last['timestamp'] as Timestamp).toDate(),
      'avgMemberCount': memberCounts.isEmpty
          ? 0
          : memberCounts.reduce((a, b) => a + b) / memberCounts.length,
    };
  }
}
