import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/group_admin.dart';
import '../../security/role_normalizer.dart';

/// Service d'administration des demandes Admin Groupe.
///
/// Le self-service crée seulement `group_admin_requests/{uid}`.
/// Ce service est réservé aux admins MASLIVE/superAdmins et transforme une
/// demande validée en profil `group_admins/{uid}` + code actif.
class GroupAdminRequestService {
  static final GroupAdminRequestService instance = GroupAdminRequestService._();
  GroupAdminRequestService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('group_admin_requests');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPendingRequests() {
    return _requests
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamReviewedRequests() {
    return _requests
        .where('status', whereIn: ['approved', 'rejected'])
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots();
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

  Future<String> _generateUniqueAdminCode() async {
    final random = Random();
    var attempts = 0;
    const maxAttempts = 100;

    while (attempts < maxAttempts) {
      final code = random.nextInt(1000000).toString().padLeft(6, '0');
      final doc = await _firestore.collection('group_admin_codes').doc(code).get();
      if (!doc.exists) return code;
      attempts++;
    }

    throw Exception('Impossible de générer un code admin unique.');
  }

  Future<GroupAdmin> approveRequest(String requestUid) async {
    final reviewer = _auth.currentUser;
    if (reviewer == null) throw Exception('Administrateur non connecté.');
    if (!await _currentUserIsMasterAdmin()) {
      throw Exception('Validation réservée aux administrateurs MASLIVE.');
    }

    final requestRef = _requests.doc(requestUid);
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) throw Exception('Demande Admin Groupe introuvable.');

    final requestData = requestDoc.data()!;
    if (requestData['status'] != 'pending') {
      throw Exception('Cette demande a déjà été traitée.');
    }

    final displayName = (requestData['displayName'] as String? ?? '').trim();
    if (displayName.isEmpty) throw Exception('Nom affiché manquant dans la demande.');

    final adminGroupId = await _generateUniqueAdminCode();
    final now = DateTime.now();
    final admin = GroupAdmin(
      uid: requestUid,
      adminGroupId: adminGroupId,
      displayName: displayName,
      isVisible: true,
      createdAt: now,
      updatedAt: now,
    );

    final adminCode = GroupAdminCode(
      adminGroupId: adminGroupId,
      adminUid: requestUid,
      createdAt: now,
      isActive: true,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('group_admins').doc(requestUid), admin.toFirestore());
    batch.set(_firestore.collection('group_admin_codes').doc(adminGroupId), adminCode.toFirestore());
    batch.set(
      _firestore.collection('users').doc(requestUid),
      {
        'role': RoleNormalizer.group,
        'groupId': adminGroupId,
        'isAdmin': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      requestRef,
      {
        'status': 'approved',
        'adminGroupId': adminGroupId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewer.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return admin;
  }

  Future<void> rejectRequest(String requestUid, {String? reason}) async {
    final reviewer = _auth.currentUser;
    if (reviewer == null) throw Exception('Administrateur non connecté.');
    if (!await _currentUserIsMasterAdmin()) {
      throw Exception('Rejet réservé aux administrateurs MASLIVE.');
    }

    await _requests.doc(requestUid).set(
      {
        'status': 'rejected',
        'rejectionReason': reason?.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewer.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
