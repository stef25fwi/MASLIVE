// Service de liaison Admin/Tracker
// Gère la création des codes, validation, rattachement

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_admin.dart';
import '../../models/group_tracker.dart';

class GroupLinkService {
  static final GroupLinkService instance = GroupLinkService._();
  GroupLinkService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // Génère un code unique à 6 chiffres
  Future<String> generateUniqueAdminCode() async {
    final random = Random();
    int attempts = 0;
    const maxAttempts = 100;

    while (attempts < maxAttempts) {
      // Génère code 000000 à 999999
      final code = random.nextInt(1000000).toString().padLeft(6, '0');

      // Vérifie si déjà utilisé
      final doc = await _firestore
          .collection('group_admin_codes')
          .doc(code)
          .get();

      if (!doc.exists) {
        return code;
      }

      attempts++;
    }

    throw Exception('Impossible de générer un code unique après $maxAttempts tentatives');
  }

  // Crée un profil admin avec code
  Future<GroupAdmin> createAdminProfile({
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Génère code unique
    final adminGroupId = await generateUniqueAdminCode();

    final now = DateTime.now();
    final admin = GroupAdmin(
      uid: user.uid,
      adminGroupId: adminGroupId,
      displayName: displayName,
      isVisible: true,
      createdAt: now,
      updatedAt: now,
    );

    // Écrit le profil admin
    await _firestore
        .collection('group_admins')
        .doc(user.uid)
        .set(admin.toFirestore());

    // Crée l'entrée dans le répertoire des codes
    final adminCode = GroupAdminCode(
      adminGroupId: adminGroupId,
      adminUid: user.uid,
      createdAt: now,
      isActive: true,
    );

    await _firestore
        .collection('group_admin_codes')
        .doc(adminGroupId)
        .set(adminCode.toFirestore());

    return admin;
  }

  // Vérifie si un code existe
  Future<GroupAdminCode?> validateAdminCode(String code) async {
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      return null;
    }

    final doc = await _firestore
        .collection('group_admin_codes')
        .doc(code)
        .get();

    if (!doc.exists) {
      return null;
    }

    final adminCode = GroupAdminCode.fromFirestore(doc);
    return adminCode.isActive ? adminCode : null;
  }

  // Rattache un tracker à un admin
  Future<GroupTracker> linkTrackerToAdmin({
    required String adminGroupId,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Valide le code
    final adminCode = await validateAdminCode(adminGroupId);
    if (adminCode == null) {
      throw Exception('Code admin invalide ou inactif');
    }

    final now = DateTime.now();
    final tracker = GroupTracker(
      uid: user.uid,
      adminGroupId: adminGroupId,
      linkedAdminUid: adminCode.adminUid,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore
        .collection('group_trackers')
        .doc(user.uid)
        .set(tracker.toFirestore());

    return tracker;
  }

  // Change le groupe d'un tracker (délie et relie)
  Future<GroupTracker> changeTrackerGroup({
    required String newAdminGroupId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Récupère le profil actuel
    final trackerDoc = await _firestore
        .collection('group_trackers')
        .doc(user.uid)
        .get();

    if (!trackerDoc.exists) {
      throw Exception('Profil tracker non trouvé');
    }

    final currentTracker = GroupTracker.fromFirestore(trackerDoc);

    // Relie au nouveau groupe
    return await linkTrackerToAdmin(
      adminGroupId: newAdminGroupId,
      displayName: currentTracker.displayName,
    );
  }

  // Délie un tracker (ne peut plus tracker)
  Future<void> unlinkTracker() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    await _firestore
        .collection('group_trackers')
        .doc(user.uid)
        .update({
      'adminGroupId': null,
      'linkedAdminUid': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Récupère le profil admin
  Future<GroupAdmin?> getAdminProfile(String uid) async {
    final doc = await _firestore
        .collection('group_admins')
        .doc(uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    return GroupAdmin.fromFirestore(doc);
  }

  // Récupère le profil tracker
  Future<GroupTracker?> getTrackerProfile(String uid) async {
    final doc = await _firestore
        .collection('group_trackers')
        .doc(uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    return GroupTracker.fromFirestore(doc);
  }

  // Stream du profil admin
  Stream<GroupAdmin?> streamAdminProfile(String uid) {
    return _firestore
        .collection('group_admins')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? GroupAdmin.fromFirestore(doc) : null);
  }

  // Stream du profil tracker
  Stream<GroupTracker?> streamTrackerProfile(String uid) {
    return _firestore
        .collection('group_trackers')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? GroupTracker.fromFirestore(doc) : null);
  }

  // Liste des trackers rattachés à un admin
  Stream<List<GroupTracker>> streamAdminTrackers(String adminGroupId) {
    return _firestore
        .collection('group_trackers')
        .where('adminGroupId', isEqualTo: adminGroupId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupTracker.fromFirestore(doc))
            .toList());
  }

  // Met à jour la visibilité du groupe admin
  Future<void> updateAdminVisibility({
    required String adminUid,
    required bool isVisible,
  }) async {
    await _firestore
        .collection('group_admins')
        .doc(adminUid)
        .update({
      'isVisible': isVisible,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Met à jour la carte sélectionnée
  Future<void> updateSelectedMap({
    required String adminUid,
    required String mapId,
  }) async {
    await _firestore
        .collection('group_admins')
        .doc(adminUid)
        .update({
      'selectedMapId': mapId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
