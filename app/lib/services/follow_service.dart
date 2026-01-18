import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService {
  FollowService._();
  static final instance = FollowService._();

  CollectionReference<Map<String, dynamic>> _followCol(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followingGroups');
  }

  Stream<Set<String>> followingGroupIdsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _followCol(uid).snapshots().map((snap) {
      return snap.docs.map((d) => d.id).toSet();
    });
  }

  Future<void> toggleFollowGroup(String groupId,
      {Map<String, dynamic>? payload}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    final ref = _followCol(uid).doc(groupId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        ...?payload,
      });
    }
  }
}
