import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class GroupPresence {
  final GeoPoint? avgPos;
  final GeoPoint? snappedAvgPos;
  final int countActive;
  final DateTime? lastUpdate;
  final double? quality;

  const GroupPresence({
    required this.avgPos,
    required this.snappedAvgPos,
    required this.countActive,
    required this.lastUpdate,
    required this.quality,
  });

  static GroupPresence fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final ts = d['lastUpdate'];

    return GroupPresence(
      avgPos: d['avgPos'] as GeoPoint?,
      snappedAvgPos: d['snappedAvgPos'] as GeoPoint?,
      countActive: (d['countActive'] as num?)?.toInt() ?? 0,
      lastUpdate: ts is Timestamp ? ts.toDate() : null,
      quality: (d['quality'] as num?)?.toDouble(),
    );
  }
}

class GroupPresenceProvider extends ChangeNotifier {
  GroupPresenceProvider({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  GroupPresence? presence;
  bool loading = false;
  Object? error;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  void watch({
    required String projectId,
    required String groupId,
  }) {
    _sub?.cancel();
    loading = true;
    error = null;
    notifyListeners();

    final ref = _db
        .collection('map_projects')
        .doc(projectId)
        .collection('group_presence')
        .doc(groupId);

    _sub = ref.snapshots().listen(
      (snap) {
        loading = false;
        error = null;

        if (snap.exists) {
          presence = GroupPresence.fromDoc(snap);
        } else {
          presence = null;
        }

        notifyListeners();
      },
      onError: (e) {
        loading = false;
        error = e;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
