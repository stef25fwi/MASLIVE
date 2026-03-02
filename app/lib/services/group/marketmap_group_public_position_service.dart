import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/group_circuit_public_position.dart';
import '../market_map_service.dart';

class MarketMapGroupPublicPositionService {
  static final MarketMapGroupPublicPositionService instance =
      MarketMapGroupPublicPositionService._();

  MarketMapGroupPublicPositionService._({FirebaseFirestore? firestore})
      : _marketMap = MarketMapService(firestore: firestore);

  final MarketMapService _marketMap;

  CollectionReference<Map<String, dynamic>> _groupTrackingCol({
    required String countryId,
    required String eventId,
    required String circuitId,
  }) {
    return _marketMap
        .circuitRef(
          countryId: countryId,
          eventId: eventId,
          circuitId: circuitId,
        )
        .collection('group_tracking');
  }

  Stream<List<GroupCircuitPublicPosition>> streamCircuitGroupPositions({
    required String countryId,
    required String eventId,
    required String circuitId,
  }) {
    return _groupTrackingCol(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
    ).snapshots().map((snapshot) {
      final out = <GroupCircuitPublicPosition>[];
      for (final doc in snapshot.docs) {
        final parsed = GroupCircuitPublicPosition.fromFirestore(doc);
        if (parsed != null) out.add(parsed);
      }
      return out;
    });
  }

  Future<void> deleteGroupPosition({
    required String countryId,
    required String eventId,
    required String circuitId,
    required String adminGroupId,
  }) {
    return _groupTrackingCol(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
    ).doc(adminGroupId).delete();
  }

  Future<void> upsertGroupPosition({
    required String countryId,
    required String eventId,
    required String circuitId,
    required String adminGroupId,
    required String adminUid,
    required String displayName,
    required double lat,
    required double lng,
    int? memberCount,
  }) {
    // Note: en prod, on privilégie l’écriture via Cloud Functions (Admin SDK)
    // pour garder une surface d’attaque minimale côté client.
    return _groupTrackingCol(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
    ).doc(adminGroupId).set({
      'adminGroupId': adminGroupId,
      'adminUid': adminUid,
      'displayName': displayName,
      'position': GeoPoint(lat, lng),
      'lat': lat,
      'lng': lng,
      if (memberCount != null) 'memberCount': memberCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
