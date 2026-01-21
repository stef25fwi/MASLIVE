import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role_model.dart';

/// Service de gestion des permissions et rôles utilisateur
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  static PermissionService get instance => _instance;
  PermissionService._internal();

  factory PermissionService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache local des définitions de rôles
  Map<String, RoleDefinition>? _rolesCache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Récupérer toutes les définitions de rôles
  Future<List<RoleDefinition>> getAllRoles() async {
    try {
      final snapshot = await _firestore.collection('roles').get();
      return snapshot.docs
          .map((doc) => RoleDefinition.fromFirestore(doc))
          .where((role) => role.isActive)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
    } catch (e) {
      // En cas d'erreur, retourner les rôles par défaut
      return RoleDefinition.defaultRoles;
    }
  }

  /// Récupérer une définition de rôle par son ID
  Future<RoleDefinition?> getRoleDefinition(String roleId) async {
    try {
      // Vérifier le cache
      if (_rolesCache != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _rolesCache![roleId];
      }

      // Recharger depuis Firestore
      final doc = await _firestore.collection('roles').doc(roleId).get();
      if (doc.exists) {
        return RoleDefinition.fromFirestore(doc);
      }

      // Retourner le rôle par défaut correspondant
      return RoleDefinition.defaultRoles
          .firstWhere((r) => r.id == roleId, orElse: () => RoleDefinition.defaultUserRole);
    } catch (e) {
      return null;
    }
  }

  /// Recharger le cache des rôles
  Future<void> reloadRolesCache() async {
    try {
      final roles = await getAllRoles();
      _rolesCache = {for (var role in roles) role.id: role};
      _cacheTime = DateTime.now();
    } catch (e) {
      // Ignorer les erreurs de rechargement
    }
  }

  /// Vérifier si un utilisateur a une permission spécifique
  Future<bool> hasPermission(
    String userId,
    Permission permission, {
    String? groupId,
  }) async {
    try {
      // Récupérer le profil utilisateur
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final roleString = userData['role'] as String? ?? 'user';
      
      // Vérifier si c'est un admin master (backwards compatibility)
      final isAdmin = userData['isAdmin'] as bool? ?? false;
      if (isAdmin) return true;

      // Récupérer la définition du rôle
      final roleDef = await getRoleDefinition(roleString);
      if (roleDef == null) return false;

      // Vérifier si le rôle a la permission
      if (roleDef.permissions.contains(permission)) {
        // Pour les permissions de groupe, vérifier que l'utilisateur appartient au bon groupe
        if (_isGroupPermission(permission) && groupId != null) {
          final userGroupId = userData['groupId'] as String?;
          return userGroupId == groupId;
        }
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Vérifier si un utilisateur a au moins une des permissions
  Future<bool> hasAnyPermission(
    String userId,
    List<Permission> permissions, {
    String? groupId,
  }) async {
    for (final permission in permissions) {
      if (await hasPermission(userId, permission, groupId: groupId)) {
        return true;
      }
    }
    return false;
  }

  /// Vérifier si un utilisateur a toutes les permissions
  Future<bool> hasAllPermissions(
    String userId,
    List<Permission> permissions, {
    String? groupId,
  }) async {
    for (final permission in permissions) {
      if (!await hasPermission(userId, permission, groupId: groupId)) {
        return false;
      }
    }
    return true;
  }

  /// Obtenir toutes les permissions d'un utilisateur
  Future<List<Permission>> getUserPermissions(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final roleString = userData['role'] as String? ?? 'user';
      
      // Admin master a toutes les permissions
      final isAdmin = userData['isAdmin'] as bool? ?? false;
      if (isAdmin) return Permission.values;

      final roleDef = await getRoleDefinition(roleString);
      return roleDef?.permissions ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Vérifier si une permission est liée à un groupe
  bool _isGroupPermission(Permission permission) {
    return [
      Permission.manageGroupInfo,
      Permission.manageGroupProducts,
      Permission.viewGroupOrders,
      Permission.viewGroupStats,
      Permission.manageGroupMembers,
    ].contains(permission);
  }

  /// Convertir UserRoleType en string
  String _roleTypeToString(UserRoleType type) {
    return type.toString().split('.').last;
  }

  /// Attribuer un rôle à un utilisateur (admin uniquement)
  Future<void> assignRole({
    required String userId,
    required UserRoleType roleType,
    String? groupId,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'role': _roleTypeToString(roleType),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Si c'est un rôle groupe, le groupId est requis
      if (roleType == UserRoleType.group) {
        if (groupId == null) {
          throw Exception('groupId requis pour le rôle groupe');
        }
        updates['groupId'] = groupId;
      } else {
        // Réinitialiser le groupId pour les autres rôles
        updates['groupId'] = null;
      }

      // Mettre à jour isAdmin pour la rétrocompatibilité
      updates['isAdmin'] = roleType == UserRoleType.admin || 
                           roleType == UserRoleType.superAdmin;

      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  /// Créer ou mettre à jour une définition de rôle (super admin uniquement)
  Future<void> saveRoleDefinition(RoleDefinition role) async {
    try {
      await _firestore
          .collection('roles')
          .doc(role.id)
          .set(role.toFirestore(), SetOptions(merge: true));
      
      // Invalider le cache
      _rolesCache = null;
      _cacheTime = null;
    } catch (e) {
      rethrow;
    }
  }

  /// Initialiser les rôles par défaut dans Firestore
  Future<void> initializeDefaultRoles() async {
    try {
      final batch = _firestore.batch();
      
      for (final role in RoleDefinition.defaultRoles) {
        final ref = _firestore.collection('roles').doc(role.id);
        batch.set(ref, role.toFirestore(), SetOptions(merge: true));
      }
      
      await batch.commit();
      
      // Recharger le cache
      await reloadRolesCache();
    } catch (e) {
      rethrow;
    }
  }

  /// Obtenir un résumé des permissions d'un utilisateur
  Future<Map<String, dynamic>> getUserPermissionsSummary(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'role': 'none',
          'permissions': <String>[],
          'permissionCount': 0,
        };
      }

      final userData = userDoc.data()!;
      final roleString = userData['role'] as String? ?? 'user';
      final isAdmin = userData['isAdmin'] as bool? ?? false;
      final groupId = userData['groupId'] as String?;

      final permissions = await getUserPermissions(userId);
      final roleDef = await getRoleDefinition(roleString);

      return {
        'userId': userId,
        'role': roleString,
        'roleName': roleDef?.name ?? 'Utilisateur',
        'roleDescription': roleDef?.description ?? '',
        'priority': roleDef?.priority ?? 0,
        'isAdmin': isAdmin,
        'groupId': groupId,
        'permissions': permissions.map((p) => p.toString().split('.').last).toList(),
        'permissionCount': permissions.length,
        'permissionsByCategory': _groupPermissionsByCategory(permissions),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Grouper les permissions par catégorie
  Map<String, List<String>> _groupPermissionsByCategory(List<Permission> permissions) {
    final Map<String, List<String>> grouped = {};
    
    for (final permission in permissions) {
      final category = permission.category;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(permission.displayName);
    }
    
    return grouped;
  }

  /// Vérifier si un utilisateur peut gérer un autre utilisateur
  Future<bool> canManageUser(String managerId, String targetUserId) async {
    try {
      // Récupérer les deux profils
      final managerDoc = await _firestore.collection('users').doc(managerId).get();
      final targetDoc = await _firestore.collection('users').doc(targetUserId).get();
      
      if (!managerDoc.exists || !targetDoc.exists) return false;

      final managerData = managerDoc.data()!;
      final targetData = targetDoc.data()!;

      // Super admin peut tout faire
      final managerRole = managerData['role'] as String? ?? 'user';
      if (managerRole == 'superAdmin') return true;

      // Admin peut gérer les utilisateurs non-admin
      if (managerRole == 'admin') {
        final targetRole = targetData['role'] as String? ?? 'user';
        return !['admin', 'superAdmin'].contains(targetRole);
      }

      // Admin groupe peut gérer les membres de son groupe
      if (managerRole == 'group') {
        final managerGroupId = managerData['groupId'] as String?;
        final targetGroupId = targetData['groupId'] as String?;
        final targetRole = targetData['role'] as String? ?? 'user';
        
        return managerGroupId != null &&
               managerGroupId == targetGroupId &&
               targetRole == 'user';
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si l'utilisateur actuel est un superadmin
  Future<bool> isCurrentUserSuperAdmin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final role = userData['role'] as String? ?? 'user';
      final isAdmin = userData['isAdmin'] as bool? ?? false;

      // Superadmin ou isAdmin + role admin
      return role == 'superAdmin' || role == 'superadmin' || 
             (isAdmin && (role == 'admin' || role == 'Admin'));
    } catch (e) {
      return false;
    }
  }
}
