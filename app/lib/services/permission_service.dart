import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_role_model.dart';
import '../security/role_normalizer.dart';

/// Service de gestion des permissions et rôles utilisateur.
///
/// Source de vérité côté client : rôle canonique + définition de rôle Firestore.
/// Important : `isAdmin=true` reste une compatibilité historique, mais ne donne
/// plus automatiquement `Permission.values`. Seul `superAdmin` reçoit toutes les
/// permissions.
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  static PermissionService get instance => _instance;
  PermissionService._internal();

  factory PermissionService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, RoleDefinition>? _rolesCache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  Future<List<RoleDefinition>> getAllRoles() async {
    try {
      final snapshot = await _firestore.collection('roles').get();
      return snapshot.docs
          .map((doc) => RoleDefinition.fromFirestore(doc))
          .where((role) => role.isActive)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
    } catch (_) {
      return RoleDefinition.defaultRoles;
    }
  }

  Future<RoleDefinition?> getRoleDefinition(String roleId) async {
    final canonicalRoleId = RoleNormalizer.normalize(roleId);
    try {
      if (_rolesCache != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _rolesCache![canonicalRoleId];
      }

      final doc = await _firestore.collection('roles').doc(canonicalRoleId).get();
      if (doc.exists) {
        return RoleDefinition.fromFirestore(doc);
      }

      return RoleDefinition.defaultRoles.firstWhere(
        (role) => role.id == canonicalRoleId,
        orElse: () => RoleDefinition.defaultUserRole,
      );
    } catch (_) {
      return RoleDefinition.defaultRoles.firstWhere(
        (role) => role.id == canonicalRoleId,
        orElse: () => RoleDefinition.defaultUserRole,
      );
    }
  }

  Future<void> reloadRolesCache() async {
    try {
      final roles = await getAllRoles();
      _rolesCache = {for (final role in roles) role.id: role};
      _cacheTime = DateTime.now();
    } catch (_) {
      // Ignorer les erreurs de rechargement.
    }
  }

  Future<bool> hasPermission(
    String userId,
    Permission permission, {
    String? groupId,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final isAdminFlag = userData['isAdmin'] as bool? ?? false;
      final canonicalRole = RoleNormalizer.normalize(
        userData['role'] as String?,
        isAdminFlag: isAdminFlag,
      );

      if (canonicalRole == RoleNormalizer.superAdmin) {
        return true;
      }

      final roleDef = await getRoleDefinition(canonicalRole);
      if (roleDef == null || !roleDef.permissions.contains(permission)) {
        return false;
      }

      if (_isGroupPermission(permission)) {
        if (groupId == null || groupId.isEmpty) return true;
        final userGroupId = userData['groupId'] as String?;
        return userGroupId == groupId;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

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

  Future<List<Permission>> getUserPermissions(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final canonicalRole = RoleNormalizer.normalize(
        userData['role'] as String?,
        isAdminFlag: userData['isAdmin'] as bool? ?? false,
      );

      if (canonicalRole == RoleNormalizer.superAdmin) {
        return Permission.values;
      }

      final roleDef = await getRoleDefinition(canonicalRole);
      return roleDef?.permissions ?? const <Permission>[];
    } catch (_) {
      return const <Permission>[];
    }
  }

  bool _isGroupPermission(Permission permission) {
    return const <Permission>[
      Permission.manageGroupInfo,
      Permission.manageGroupProducts,
      Permission.viewGroupOrders,
      Permission.viewGroupStats,
      Permission.manageGroupMembers,
    ].contains(permission);
  }

  String _roleTypeToString(UserRoleType type) => type.toString().split('.').last;

  Future<void> assignRole({
    required String userId,
    required UserRoleType roleType,
    String? groupId,
  }) async {
    final canonicalRole = _roleTypeToString(roleType);
    final updates = <String, dynamic>{
      'role': canonicalRole,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (roleType == UserRoleType.group) {
      if (groupId == null || groupId.trim().isEmpty) {
        throw Exception('groupId requis pour le rôle groupe');
      }
      updates['groupId'] = groupId.trim();
    } else {
      updates['groupId'] = null;
    }

    // Compatibilité seulement : ne pas utiliser `isAdmin` comme source de droits.
    updates['isAdmin'] = roleType == UserRoleType.admin || roleType == UserRoleType.superAdmin;

    await _firestore.collection('users').doc(userId).update(updates);
  }

  Future<void> saveRoleDefinition(RoleDefinition role) async {
    await _firestore.collection('roles').doc(role.id).set(
          role.toFirestore(),
          SetOptions(merge: true),
        );
    _rolesCache = null;
    _cacheTime = null;
  }

  Future<void> initializeDefaultRoles() async {
    final batch = _firestore.batch();
    for (final role in RoleDefinition.defaultRoles) {
      batch.set(
        _firestore.collection('roles').doc(role.id),
        role.toFirestore(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    await reloadRolesCache();
  }

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
      final canonicalRole = RoleNormalizer.normalize(
        userData['role'] as String?,
        isAdminFlag: userData['isAdmin'] as bool? ?? false,
      );
      final permissions = await getUserPermissions(userId);
      final roleDef = await getRoleDefinition(canonicalRole);

      return {
        'userId': userId,
        'role': canonicalRole,
        'rawRole': userData['role'] as String? ?? 'user',
        'roleName': roleDef?.name ?? RoleNormalizer.label(canonicalRole),
        'roleDescription': roleDef?.description ?? '',
        'priority': roleDef?.priority ?? 0,
        'isAdmin': userData['isAdmin'] as bool? ?? false,
        'groupId': userData['groupId'] as String?,
        'permissions': permissions.map((p) => p.toString().split('.').last).toList(),
        'permissionCount': permissions.length,
        'permissionsByCategory': _groupPermissionsByCategory(permissions),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Map<String, List<String>> _groupPermissionsByCategory(List<Permission> permissions) {
    final grouped = <String, List<String>>{};
    for (final permission in permissions) {
      final category = _permissionCategory(permission);
      grouped.putIfAbsent(category, () => <String>[]).add(_permissionDisplayName(permission));
    }
    return grouped;
  }

  Future<bool> canManageUser(String managerId, String targetUserId) async {
    try {
      final managerDoc = await _firestore.collection('users').doc(managerId).get();
      final targetDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (!managerDoc.exists || !targetDoc.exists) return false;

      final managerData = managerDoc.data()!;
      final targetData = targetDoc.data()!;
      final managerRole = RoleNormalizer.normalize(
        managerData['role'] as String?,
        isAdminFlag: managerData['isAdmin'] as bool? ?? false,
      );
      final targetRole = RoleNormalizer.normalize(
        targetData['role'] as String?,
        isAdminFlag: targetData['isAdmin'] as bool? ?? false,
      );

      if (managerRole == RoleNormalizer.superAdmin) return true;

      if (managerRole == RoleNormalizer.admin) {
        return !<String>[RoleNormalizer.admin, RoleNormalizer.superAdmin].contains(targetRole);
      }

      if (managerRole == RoleNormalizer.group) {
        final managerGroupId = managerData['groupId'] as String?;
        final targetGroupId = targetData['groupId'] as String?;
        return managerGroupId != null &&
            managerGroupId == targetGroupId &&
            targetRole == RoleNormalizer.user;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isCurrentUserSuperAdmin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      final userData = userDoc.data()!;
      return RoleNormalizer.isSuperAdmin(
        userData['role'] as String?,
        isAdminFlag: userData['isAdmin'] as bool? ?? false,
      );
    } catch (_) {
      return false;
    }
  }

  String _permissionCategory(Permission permission) {
    final name = permission.toString().split('.').last;
    if (name.startsWith('manageGroup') || name.startsWith('viewGroup')) return 'Groupe';
    if (name.startsWith('manageAll') || name == 'moderateContent' || name == 'viewAllStats') {
      return 'Administration';
    }
    if (name == 'manageRoles' || name == 'managePermissions' || name == 'deleteAnyContent') {
      return 'SuperAdmin';
    }
    if (name == 'updateLocation' || name == 'viewTracking') return 'Tracking';
    return 'Utilisateur';
  }

  String _permissionDisplayName(Permission permission) {
    return permission
        .toString()
        .split('.')
        .last
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .trim();
  }
}
