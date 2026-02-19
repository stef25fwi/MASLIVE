import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/market_circuit_models.dart';
import 'circuit_repository.dart';

typedef LngLat = ({double lng, double lat});

class CircuitVersioningService {
  CircuitVersioningService({
    CircuitRepository? repository,
    FirebaseFirestore? firestore,
  })  : _repository = repository ?? CircuitRepository(firestore: firestore),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final CircuitRepository _repository;
  final FirebaseFirestore _firestore;

  Future<void> lockProject({
    required String projectId,
    required String uid,
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(ttl);
    await _firestore.collection('map_projects').doc(projectId).set({
      'editLock': {
        'lockedBy': uid,
        'lockedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
      }
    }, SetOptions(merge: true));
  }

  Future<void> unlockProject({required String projectId}) async {
    await _firestore.collection('map_projects').doc(projectId).set({
      'editLock': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> saveDraftVersion({
    required String projectId,
    required String actorUid,
    required String actorRole,
    required String groupId,
    required Map<String, dynamic> currentData,
    required List<MarketMapLayer> layers,
    required List<MarketMapPOI> pois,
  }) {
    return _repository.createDraftSnapshot(
      projectId: projectId,
      actorUid: actorUid,
      actorRole: actorRole,
      groupId: groupId,
      currentData: currentData,
      layers: layers,
      pois: pois,
    );
  }

  Future<List<CircuitDraftVersion>> listDrafts({
    required String projectId,
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    return _repository.listDrafts(
      projectId: projectId,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  }

  Future<void> restoreDraft({
    required String projectId,
    required String draftId,
    required String actorUid,
    required String actorRole,
    required String groupId,
  }) async {
    await lockProject(projectId: projectId, uid: actorUid);
    try {
      await _repository.restoreDraft(
        projectId: projectId,
        draftId: draftId,
        actorUid: actorUid,
        actorRole: actorRole,
        groupId: groupId,
      );
    } finally {
      await unlockProject(projectId: projectId);
    }
  }
}
