import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  FavoritesService._();
  static final instance = FavoritesService._();

  CollectionReference<Map<String, dynamic>> _favCol(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites');
  }

  Stream<Set<String>> favoritesIdsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _favCol(uid).snapshots().map((snap) {
      return snap.docs.map((d) => d.id).toSet();
    });
  }

  Future<void> toggleFavoritePlace(String placeId,
      {Map<String, dynamic>? payload}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    final ref = _favCol(uid).doc(placeId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'type': 'place',
        'createdAt': FieldValue.serverTimestamp(),
        ...?payload,
      });
    }
  }
}
