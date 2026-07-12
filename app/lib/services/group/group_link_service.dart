// Service de liaison Admin/Tracker
// Gère la création des codes, validation, rattachement

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/group_admin.dart';
import '../../models/group_tracker.dart';
import '../../security/role_normalizer.dart';

class GroupLinkService {
  static final GroupLinkService instance = GroupLinkService._();
  GroupLinkService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Future<String> generateUniqueAdminCode() async {
    final random = Random();
    var attempts = 0;
    const maxAttempts = 100;

    while (attempts < maxAttempts) {
      final code = random.nextInt(1000000).toString().padLeft(6, '0');
      final doc = await _firestore.collection('group_admin_codes').doc(code).get();
      if (!doc.exists) return code;
      attempts++;
    }

    throw Exception('Impossible de générer un code unique après $maxAttempts tentatives');
  }

  /// Crée une demande d'activation Admin Groupe.
  ///
  /// Les utilisateurs standards ne créent plus directement `group_admins` :
  /// la demande doit être validée par l'administration MASLIVE, puis la création
  /// réelle peut être faite côté admin/Cloud Function.
  Future<void> requestAdminProfile({required String displayName}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final cleanName = displayName.trim();
    if (cleanName.isEmpty) {
      throw Exception('Nom d\'affichage requis');
    }

    await _firestore.collection('group_admin_requests').doc(user.uid).set({
      'requestUid': user.uid,
      'displayName': cleanName,
      'email': user.email,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamOwnAdminRequest() {
    final uid = currentUid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore.collection('group_admin_requests').doc(uid).snapshots();
  }

  Future<bool> _currentUserIsMasterAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    return RoleNormalizer.isMasterAdmin(
      data?['role'] as String?,
      isAdminFlag: data?['isAdmin'] == true,
    );
  }

  /// Crée réellement le profil admin groupe.
  ///
  /// Réservé aux comptes master admin. Pour un utilisateur standard, cette
  /// méthode enregistre une demande et signale que la validation est requise.
  Future<GroupAdmin> createAdminProfile({required String displayName}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    if (!await _currentUserIsMasterAdmin()) {
      await requestAdminProfile(displayName: displayName);
      throw Exception('Demande Admin Groupe envoyée. Validation MASLIVE requise avant activation.');
    }

    final adminGroupId = await generateUniqueAdminCode();
    final now = DateTime.now();
    final admin = GroupAdmin(
      uid: user.uid,
      adminGroupId: adminGroupId,
      displayName: displayName.trim(),
      isVisible: true,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('group_admins').doc(user.uid).set(admin.toFirestore());

    final adminCode = GroupAdminCode(
      adminGroupId: adminGroupId,
      adminUid: user.uid,
      createdAt: now,
      isActive: true,
    );

    await _firestore.collection('group_admin_codes').doc(adminGroupId).set(adminCode.toFirestore());

    await _firestore.collection('users').doc(user.uid).set({
      'role': RoleNormalizer.group,
      'groupId': adminGroupId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return admin;
  }

  Future<GroupAdminCode?> validateAdminCode(String code) async {
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) return null;
    final doc = await _firestore.collection('group_admin_codes').doc(code).get();
    if (!doc.exists) return null;
    final adminCode = GroupAdminCode.fromFirestore(doc);
    return adminCode.isActive ? adminCode : null;
  }

  Future<GroupTracker> linkTrackerToAdmin({
    required String adminGroupId,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final adminCode = await validateAdminCode(adminGroupId);
    if (adminCode == null) throw Exception('Code admin invalide ou inactif');

    final now = DateTime.now();
    final tracker = GroupTracker(
      uid: user.uid,
      adminGroupId: adminGroupId,
      linkedAdminUid: adminCode.adminUid,
      displayName: displayName.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('group_trackers').doc(user.uid).set(tracker.toFirestore());
    await _firestore.collection('users').doc(user.uid).set({
      'role': RoleNormalizer.tracker,
      'groupId': adminGroupId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return tracker;
  }

  Future<GroupTracker> changeTrackerGroup({required String newAdminGroupId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final trackerDoc = await _firestore.collection('group_trackers').doc(user.uid).get();
    if (!trackerDoc.exists) throw Exception('Profil tracker non trouvé');

    final currentTracker = GroupTracker.fromFirestore(trackerDoc);
    return linkTrackerToAdmin(
      adminGroupId: newAdminGroupId,
      displayName: currentTracker.displayName,
    );
  }

  Future<void> unlinkTracker() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    await _firestore.collection('group_trackers').doc(user.uid).update({
      'adminGroupId': null,
      'linkedAdminUid': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).set({
      'role': RoleNormalizer.user,
      'groupId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<GroupAdmin?> getAdminProfile(String uid) async {
    final doc = await _firestore.collection('group_admins').doc(uid).get();
    if (!doc.exists) return null;
    return GroupAdmin.fromFirestore(doc);
  }

  Future<GroupTracker?> getTrackerProfile(String uid) async {
    final doc = await _firestore.collection('group_trackers').doc(uid).get();
    if (!doc.exists) return null;
    return GroupTracker.fromFirestore(doc);
  }

  Stream<GroupAdmin?> streamAdminProfile(String uid) {
    return _firestore
        .collection('group_admins')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? GroupAdmin.fromFirestore(doc) : null);
  }

  Stream<GroupTracker?> streamTrackerProfile(String uid) {
    return _firestore
        .collection('group_trackers')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? GroupTracker.fromFirestore(doc) : null);
  }

  Stream<List<GroupTracker>> streamAdminTrackers(String adminGroupId) {
    return _firestore
        .collection('group_trackers')
        .where('adminGroupId', isEqualTo: adminGroupId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GroupTracker.fromFirestore(doc)).toList());
  }

  Stream<List<GroupAdmin>> streamAllAdmins() {
    return _firestore
        .collection('group_admins')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GroupAdmin.fromFirestore(doc)).toList());
  }

  Future<void> linkExistingTrackerToAdmin({
    required String trackerUid,
    required String adminGroupId,
    required String linkedAdminUid,
  }) async {
    final trackerRef = _firestore.collection('group_trackers').doc(trackerUid);
    final trackerDoc = await trackerRef.get();
    if (!trackerDoc.exists) throw Exception('Tracker introuvable: $trackerUid');

    await trackerRef.update({
      'adminGroupId': adminGroupId,
      'linkedAdminUid': linkedAdminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(trackerUid).set({
      'role': RoleNormalizer.tracker,
      'groupId': adminGroupId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlinkTrackerByUid({required String trackerUid}) async {
    await _firestore.collection('group_trackers').doc(trackerUid).update({
      'adminGroupId': null,
      'linkedAdminUid': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(trackerUid).set({
      'role': RoleNormalizer.user,
      'groupId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateAdminVisibility({
    required String adminUid,
    required bool isVisible,
  }) async {
    await _firestore.collection('group_admins').doc(adminUid).update({
      'isVisible': isVisible,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSelectedMap({
    required String adminUid,
    required String mapId,
  }) async {
    await _firestore.collection('group_admins').doc(adminUid).update({
      'selectedMapId': mapId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSelectedCircuit({
    required String adminUid,
    required GroupSelectedCircuit selectedCircuit,
  }) async {
    await _firestore.collection('group_admins').doc(adminUid).update({
      'selectedCircuit': selectedCircuit.toMap(),
      'isVisible': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
