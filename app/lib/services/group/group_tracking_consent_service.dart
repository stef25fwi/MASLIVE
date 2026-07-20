import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Journalise l'accord explicite donné avant le démarrage d'un tracking groupe.
class GroupTrackingConsentService {
  GroupTrackingConsentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final GroupTrackingConsentService instance =
      GroupTrackingConsentService();

  static const String consentVersion = '2026-07-19-v1';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> recordAcceptance({
    required String adminGroupId,
    required String role,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté');
    }

    final normalizedRole = role == 'admin' ? 'admin' : 'tracker';
    final consentId = 'group_$adminGroupId';

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tracking_consents')
        .doc(consentId)
        .set(
      <String, dynamic>{
        'accepted': true,
        'version': consentVersion,
        'adminGroupId': adminGroupId,
        'role': normalizedRole,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
