import 'package:cloud_firestore/cloud_firestore.dart';

class AuditTarget {
  const AuditTarget({
    required this.projectId,
    required this.groupId,
    this.draftId,
    this.marketMapPath,
  });

  final String projectId;
  final String groupId;
  final String? draftId;
  final String? marketMapPath;

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'groupId': groupId,
      if (draftId != null) 'draftId': draftId,
      if (marketMapPath != null) 'marketMapPath': marketMapPath,
    };
  }
}

class AuditDiffSummary {
  const AuditDiffSummary({
    this.routePointsDelta,
    this.poiDelta,
    this.perimeterChanged,
    this.styleChangedKeys,
  });

  final int? routePointsDelta;
  final int? poiDelta;
  final bool? perimeterChanged;
  final List<String>? styleChangedKeys;

  Map<String, dynamic> toJson() {
    return {
      if (routePointsDelta != null) 'routePointsDelta': routePointsDelta,
      if (poiDelta != null) 'poiDelta': poiDelta,
      if (perimeterChanged != null) 'perimeterChanged': perimeterChanged,
      if (styleChangedKeys != null) 'styleChangedKeys': styleChangedKeys,
    };
  }
}

class AuditLogger {
  AuditLogger({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _firestore.collection('audit_events');

  DocumentReference<Map<String, dynamic>> writeInBatch({
    required WriteBatch batch,
    required String actorUid,
    required String actorRole,
    required String action,
    required AuditTarget target,
    AuditDiffSummary? diffSummary,
  }) {
    final ref = _eventsCol.doc();
    batch.set(ref, {
      'at': FieldValue.serverTimestamp(),
      'actorUid': actorUid,
      'actorRole': actorRole,
      'action': action,
      'target': target.toJson(),
      'diffSummary': (diffSummary ?? const AuditDiffSummary()).toJson(),
    });
    return ref;
  }
}
