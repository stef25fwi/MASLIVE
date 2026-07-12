import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../security/role_normalizer.dart';

/// Service pour gérer les custom claims d'authentification.
class AuthClaimsService {
  static final AuthClaimsService _instance = AuthClaimsService._internal();
  static AuthClaimsService get instance => _instance;
  AuthClaimsService._internal();

  factory AuthClaimsService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>?> getCurrentUserClaims() async {
    final user = currentUser;
    if (user == null) return null;
    final idTokenResult = await user.getIdTokenResult();
    return idTokenResult.claims;
  }

  Future<Map<String, dynamic>?> _currentUserData() async {
    final user = currentUser;
    if (user == null) return null;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data();
  }

  Future<String?> getCurrentUserRole() async {
    final data = await _currentUserData();
    if (data == null) return null;
    return RoleNormalizer.normalize(
      data['role'] as String?,
      isAdminFlag: data['isAdmin'] as bool? ?? false,
    );
  }

  Future<bool> isCurrentUserAdmin() async {
    final role = await getCurrentUserRole();
    return role == RoleNormalizer.admin || role == RoleNormalizer.superAdmin;
  }

  Future<bool> isCurrentUserSuperAdmin() async {
    final role = await getCurrentUserRole();
    return role == RoleNormalizer.superAdmin;
  }

  Future<bool> hasRole(String roleToCheck) async {
    final role = await getCurrentUserRole();
    return role == RoleNormalizer.normalize(roleToCheck);
  }

  Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return null;

    return AppUser.fromFirestore(userDoc);
  }

  Stream<AppUser?> getCurrentAppUserStream() {
    final user = currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  Future<void> refreshIdToken() async {
    final user = currentUser;
    if (user != null) {
      await user.getIdToken(true);
    }
  }

  Future<bool> isAccountActive() async {
    final data = await _currentUserData();
    if (data == null) return false;
    return data['isActive'] as bool? ?? true;
  }

  Future<void> deactivateAccount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> activateAccount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> canAccessAdminPanel() => isCurrentUserAdmin();

  Future<bool> canManageUsers() => isCurrentUserAdmin();

  Future<bool> canManageRoles() => isCurrentUserSuperAdmin();

  Future<bool> canManageSystem() => isCurrentUserSuperAdmin();
}
