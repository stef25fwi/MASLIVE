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

  // L'écriture de group_tracking (upsert/delete) est assurée côté serveur par la
  // Cloud Function `publishGroupAverageToCircuit` (Admin SDK) pour garder une
  // surface d'attaque minimale côté client. Ce service est en lecture seule.
}
