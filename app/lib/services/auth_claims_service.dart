import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Service pour gérer les custom claims d'authentification
class AuthClaimsService {
  static final AuthClaimsService _instance = AuthClaimsService._internal();
  static AuthClaimsService get instance => _instance;
  AuthClaimsService._internal();

  factory AuthClaimsService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  /// Obtenir les claims de l'utilisateur actuel
  Future<Map<String, dynamic>?> getCurrentUserClaims() async {
    final user = currentUser;
    if (user == null) return null;

    final idTokenResult = await user.getIdTokenResult();
    return idTokenResult.claims;
  }

  /// Vérifier si l'utilisateur actuel est admin
  Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;

    // Vérifier d'abord dans Firestore (source de vérité)
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;

    final userData = userDoc.data()!;
    final role = userData['role'] as String? ?? 'user';
    final isAdmin = userData['isAdmin'] as bool? ?? false;

    return isAdmin || role == 'admin' || role == 'superAdmin';
  }

  /// Vérifier si l'utilisateur actuel est super admin
  Future<bool> isCurrentUserSuperAdmin() async {
    final user = currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;

    final userData = userDoc.data()!;
    final role = userData['role'] as String? ?? 'user';

    return role == 'superAdmin';
  }

  /// Vérifier si l'utilisateur actuel a un rôle spécifique
  Future<bool> hasRole(String roleToCheck) async {
    final user = currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;

    final userData = userDoc.data()!;
    final role = userData['role'] as String? ?? 'user';

    return role == roleToCheck;
  }

  /// Obtenir le rôle de l'utilisateur actuel
  Future<String?> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return null;

    final userData = userDoc.data()!;
    return userData['role'] as String? ?? 'user';
  }

  /// Obtenir l'utilisateur complet actuel
  Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return null;

    return AppUser.fromFirestore(userDoc);
  }

  /// Stream de l'utilisateur complet actuel
  Stream<AppUser?> getCurrentAppUserStream() {
    final user = currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  /// Forcer le rafraîchissement du token ID
  Future<void> refreshIdToken() async {
    final user = currentUser;
    if (user != null) {
      await user.getIdToken(true);
    }
  }

  /// Vérifier si le compte est actif
  Future<bool> isAccountActive() async {
    final user = currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;

    final userData = userDoc.data()!;
    return userData['isActive'] as bool? ?? true;
  }

  /// Désactiver un compte (admin uniquement)
  Future<void> deactivateAccount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Activer un compte (admin uniquement)
  Future<void> activateAccount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Vérifier les permissions multiples
  Future<bool> canAccessAdminPanel() async {
    return await isCurrentUserAdmin();
  }

  Future<bool> canManageUsers() async {
    return await isCurrentUserAdmin();
  }

  Future<bool> canManageRoles() async {
    return await isCurrentUserSuperAdmin();
  }

  Future<bool> canManageSystem() async {
    return await isCurrentUserSuperAdmin();
  }
}
