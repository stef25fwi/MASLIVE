import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Repository pour gérer les opérations sur les utilisateurs
class UserRepository {
  static final UserRepository _instance = UserRepository._internal();
  static UserRepository get instance => _instance;
  UserRepository._internal();

  factory UserRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtenir un utilisateur par son ID
  Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Stream d'un utilisateur
  Stream<AppUser?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  /// Obtenir tous les utilisateurs (avec pagination)
  Future<List<AppUser>> getAllUsers({
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream de tous les utilisateurs
  Stream<List<AppUser>> getAllUsersStream({int limit = 50}) {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList());
  }

  /// Rechercher des utilisateurs par email ou nom
  Future<List<AppUser>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final queryLower = query.toLowerCase();

      // Recherche par email
      final emailSnapshot = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThan: '${queryLower}z')
          .limit(20)
          .get();

      // Recherche par nom
      final nameSnapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: queryLower)
          .where('displayName', isLessThan: '${queryLower}z')
          .limit(20)
          .get();

      final users = <String, AppUser>{};

      for (final doc in emailSnapshot.docs) {
        users[doc.id] = AppUser.fromFirestore(doc);
      }

      for (final doc in nameSnapshot.docs) {
        users[doc.id] = AppUser.fromFirestore(doc);
      }

      return users.values.toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtenir les utilisateurs par rôle
  Future<List<AppUser>> getUsersByRole(String role) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtenir les utilisateurs d'un groupe
  Future<List<AppUser>> getUsersByGroup(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('groupId', isEqualTo: groupId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Créer ou mettre à jour un utilisateur
  Future<void> saveUser(AppUser user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Mettre à jour les champs d'un utilisateur
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(userId).update(updates);
  }

  /// Supprimer un utilisateur
  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  /// Obtenir le nombre total d'utilisateurs
  Future<int> getTotalUsersCount() async {
    try {
      final snapshot = await _firestore.collection('users').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Obtenir les statistiques des utilisateurs par rôle
  Future<Map<String, int>> getUserStatsByRole() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final stats = <String, int>{
        'user': 0,
        'tracker': 0,
        'group': 0,
        'admin': 0,
        'superAdmin': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final role = data['role'] as String? ?? 'user';
        stats[role] = (stats[role] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      return {};
    }
  }

  /// Obtenir les utilisateurs actifs récents
  Future<List<AppUser>> getRecentActiveUsers({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtenir les nouveaux utilisateurs
  Future<List<AppUser>> getNewUsers({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Vérifier si un email existe déjà
  Future<bool> emailExists(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Mettre à jour le rôle d'un utilisateur
  Future<void> updateUserRole(
    String userId,
    String role, {
    String? groupId,
  }) async {
    final updates = <String, dynamic>{
      'role': role,
      'isAdmin': ['admin', 'superAdmin'].contains(role),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (role == 'group') {
      if (groupId == null) {
        throw Exception('groupId requis pour le rôle groupe');
      }
      updates['groupId'] = groupId;
    } else {
      updates['groupId'] = null;
    }

    await _firestore.collection('users').doc(userId).update(updates);
  }

  /// Désactiver/Activer un utilisateur
  Future<void> toggleUserActive(String userId, bool isActive) async {
    await _firestore.collection('users').doc(userId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Obtenir le nombre d'utilisateurs actifs
  Future<int> getActiveUsersCount() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Mettre un utilisateur en maintenance
  Future<void> setMaintenance({
    required String targetUid,
    required bool enabled,
    required String reason,
    required String byUid,
  }) async {
    final now = FieldValue.serverTimestamp();

    await _firestore.collection('users').doc(targetUid).set({
      'maintenance': {
        'enabled': enabled,
        'reason': reason,
        'by': byUid,
        'at': now,
      },
      'isActive': !enabled, // Si en maintenance, désactiver le compte
      'updatedAt': now,
    }, SetOptions(merge: true));

    // Message système pour informer l'utilisateur
    await _firestore
        .collection('users')
        .doc(targetUid)
        .collection('system_messages')
        .add({
      'type': 'maintenance',
      'title': enabled ? 'Compte en maintenance' : 'Maintenance terminée',
      'body': enabled
          ? 'Un administrateur intervient sur votre compte. Certaines actions peuvent être temporairement limitées.'
          : 'Votre compte est de nouveau opérationnel.',
      'createdAt': now,
      'read': false,
      'meta': {'by': byUid, 'enabled': enabled},
    });
  }

  /// Envoyer un message système à un utilisateur
  Future<void> sendSystemMessage({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? meta,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('system_messages')
        .add({
      'type': type,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'meta': meta ?? {},
    });
  }

  /// Obtenir les messages système d'un utilisateur
  Stream<QuerySnapshot> getUserSystemMessages(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('system_messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Marquer un message système comme lu
  Future<void> markMessageAsRead(String userId, String messageId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('system_messages')
        .doc(messageId)
        .update({'read': true});
  }

  /// Obtenir le statut de maintenance d'un utilisateur
  Future<Map<String, dynamic>?> getMaintenanceStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['maintenance'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }
}
