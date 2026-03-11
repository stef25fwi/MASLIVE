import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_table_state.dart';

class RestaurantLiveTableRepository {
  RestaurantLiveTableRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String buildStatusDocId({
    required String countryId,
    required String eventId,
    required String circuitId,
    required String poiId,
  }) {
    return [countryId, eventId, circuitId, poiId]
        .map((e) => e.trim())
        .join('__');
  }

  static LiveTableState resolvePreferredState({
    Map<String, dynamic>? remoteData,
    Map<String, dynamic>? fallbackMeta,
  }) {
    LiveTableState? fallbackState;
    final meta = fallbackMeta ?? const <String, dynamic>{};
    final live = meta['liveTable'];
    if (live is Map) {
      fallbackState = LiveTableState.fromMap(
        Map<String, dynamic>.from(live),
        source: 'metadata',
      );
    }

    if (remoteData != null) {
      final remoteState = LiveTableState.fromMap(
        remoteData,
        source: 'restaurant_live_status',
      );
      if (fallbackState != null && !fallbackState.enabled) {
        final fallbackTs = fallbackState.updatedAt;
        final remoteTs = remoteState.updatedAt;
        if (fallbackTs != null && (remoteTs == null || !fallbackTs.isBefore(remoteTs))) {
          return fallbackState;
        }
      }
      return remoteState;
    }

    return fallbackState ?? LiveTableState.disabled();
  }

  Stream<LiveTableState> watchStatus({
    required String countryId,
    required String eventId,
    required String circuitId,
    required String poiId,
    Map<String, dynamic>? fallbackMeta,
  }) {
    final docId = buildStatusDocId(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
      poiId: poiId,
    );

    return _firestore
        .collection('restaurant_live_status')
        .doc(docId)
        .snapshots()
        .map((snap) {
          return resolvePreferredState(
            remoteData: snap.exists ? snap.data() : null,
            fallbackMeta: fallbackMeta,
          );
        });
  }
}
