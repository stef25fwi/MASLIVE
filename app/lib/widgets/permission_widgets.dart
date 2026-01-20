import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role_model.dart';
import '../services/permission_service.dart';

/// Widget qui affiche son contenu uniquement si l'utilisateur a la permission requise
class PermissionGuard extends StatelessWidget {
  final Permission permission;
  final String? groupId;
  final Widget child;
  final Widget? fallback;
  final bool showLoading;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.groupId,
    this.fallback,
    this.showLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return fallback ?? const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: PermissionService.instance.hasPermission(
        currentUser.uid,
        permission,
        groupId: groupId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return showLoading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == false) {
          return fallback ?? const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}

/// Widget qui affiche son contenu uniquement si l'utilisateur a AU MOINS UNE des permissions
class AnyPermissionGuard extends StatelessWidget {
  final List<Permission> permissions;
  final String? groupId;
  final Widget child;
  final Widget? fallback;
  final bool showLoading;

  const AnyPermissionGuard({
    super.key,
    required this.permissions,
    required this.child,
    this.groupId,
    this.fallback,
    this.showLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return fallback ?? const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: PermissionService.instance.hasAnyPermission(
        currentUser.uid,
        permissions,
        groupId: groupId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return showLoading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == false) {
          return fallback ?? const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}

/// Widget qui affiche son contenu uniquement si l'utilisateur a TOUTES les permissions
class AllPermissionsGuard extends StatelessWidget {
  final List<Permission> permissions;
  final String? groupId;
  final Widget child;
  final Widget? fallback;
  final bool showLoading;

  const AllPermissionsGuard({
    super.key,
    required this.permissions,
    required this.child,
    this.groupId,
    this.fallback,
    this.showLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return fallback ?? const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: PermissionService.instance.hasAllPermissions(
        currentUser.uid,
        permissions,
        groupId: groupId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return showLoading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == false) {
          return fallback ?? const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}

/// Widget qui affiche son contenu uniquement si l'utilisateur a le rôle requis
class RoleGuard extends StatelessWidget {
  final UserRoleType requiredRole;
  final Widget child;
  final Widget? fallback;
  final bool showLoading;

  const RoleGuard({
    super.key,
    required this.requiredRole,
    required this.child,
    this.fallback,
    this.showLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return fallback ?? const SizedBox.shrink();
    }

    return FutureBuilder<RoleDefinition>(
      future: _getUserRole(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return showLoading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return fallback ?? const SizedBox.shrink();
        }

        final userRole = snapshot.data!;
        
        // Vérifier la priorité du rôle
        final requiredRoleDef = RoleDefinition.defaultRoles
            .firstWhere((r) => r.roleType == requiredRole);

        if (userRole.priority >= requiredRoleDef.priority) {
          return child;
        }

        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  Future<RoleDefinition> _getUserRole(String userId) async {
    final permissions = await PermissionService.instance.getUserPermissions(userId);
    
    // Déterminer le rôle basé sur les permissions
    if (permissions.contains(Permission.manageRoles)) {
      return RoleDefinition.defaultSuperAdminRole;
    }
    if (permissions.contains(Permission.manageAllUsers)) {
      return RoleDefinition.defaultAdminRole;
    }
    if (permissions.contains(Permission.manageGroupInfo)) {
      return RoleDefinition.defaultGroupRole;
    }
    if (permissions.contains(Permission.updateLocation)) {
      return RoleDefinition.defaultTrackerRole;
    }
    
    return RoleDefinition.defaultUserRole;
  }
}

/// Builder qui fournit les permissions de l'utilisateur actuel
class UserPermissionsBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, List<Permission> permissions) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const UserPermissionsBuilder({
    super.key,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return builder(context, []);
    }

    return FutureBuilder<List<Permission>>(
      future: PermissionService.instance.getUserPermissions(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (loadingBuilder != null) {
            return loadingBuilder!(context);
          }
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(context, snapshot.error!);
          }
          return Center(
            child: Text('Erreur: ${snapshot.error}'),
          );
        }

        final permissions = snapshot.data ?? [];
        return builder(context, permissions);
      },
    );
  }
}

/// Extension sur BuildContext pour faciliter les vérifications de permissions
extension PermissionContext on BuildContext {
  /// Vérifie si l'utilisateur actuel a une permission
  Future<bool> hasPermission(Permission permission, {String? groupId}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    return PermissionService.instance.hasPermission(
      currentUser.uid,
      permission,
      groupId: groupId,
    );
  }

  /// Vérifie si l'utilisateur actuel a au moins une des permissions
  Future<bool> hasAnyPermission(
    List<Permission> permissions, {
    String? groupId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    return PermissionService.instance.hasAnyPermission(
      currentUser.uid,
      permissions,
      groupId: groupId,
    );
  }

  /// Obtient toutes les permissions de l'utilisateur actuel
  Future<List<Permission>> getUserPermissions() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    return PermissionService.instance.getUserPermissions(currentUser.uid);
  }
}
