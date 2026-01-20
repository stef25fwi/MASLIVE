import 'package:cloud_firestore/cloud_firestore.dart';

/// Énumération des rôles utilisateur avec hiérarchie
enum UserRoleType {
  user,     // Utilisateur standard
  tracker,  // Utilisateur traceur (avec permissions de localisation)
  group,    // Administrateur de groupe
  admin,    // Administrateur master
  superAdmin // Super administrateur (tous les droits)
}

/// Permissions disponibles dans le système
enum Permission {
  // Permissions de base
  readPublicContent,
  createAccount,
  updateOwnProfile,
  
  // Permissions utilisateur
  createOrder,
  viewOwnOrders,
  manageCart,
  manageFavorites,
  followGroups,
  
  // Permissions traceur
  updateLocation,
  viewTracking,
  
  // Permissions groupe
  manageGroupInfo,
  manageGroupProducts,
  viewGroupOrders,
  viewGroupStats,
  manageGroupMembers,
  
  // Permissions admin
  manageAllGroups,
  manageAllUsers,
  manageAllProducts,
  manageAllOrders,
  managePlaces,
  managePOIs,
  manageCircuits,
  viewAllStats,
  moderateContent,
  
  // Permissions super admin
  manageRoles,
  managePermissions,
  accessAdminPanel,
  deleteAnyContent,
}

/// Modèle de définition de rôle
class RoleDefinition {
  final String id;
  final String name;
  final String description;
  final UserRoleType roleType;
  final List<Permission> permissions;
  final int priority; // Plus le nombre est élevé, plus le rôle a de pouvoir
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RoleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.roleType,
    required this.permissions,
    required this.priority,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory RoleDefinition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoleDefinition(
      id: doc.id,
      name: data['name'] as String,
      description: data['description'] as String,
      roleType: _parseRoleType(data['roleType'] as String),
      permissions: (data['permissions'] as List<dynamic>?)
              ?.map((e) => _parsePermission(e as String))
              .whereType<Permission>()
              .toList() ??
          [],
      priority: data['priority'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'roleType': _roleTypeToString(roleType),
      'permissions': permissions.map((p) => _permissionToString(p)).toList(),
      'priority': priority,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  static UserRoleType _parseRoleType(String value) {
    switch (value) {
      case 'user':
        return UserRoleType.user;
      case 'tracker':
        return UserRoleType.tracker;
      case 'group':
        return UserRoleType.group;
      case 'admin':
        return UserRoleType.admin;
      case 'superAdmin':
        return UserRoleType.superAdmin;
      default:
        return UserRoleType.user;
    }
  }

  static String _roleTypeToString(UserRoleType type) {
    return type.toString().split('.').last;
  }

  static Permission? _parsePermission(String value) {
    try {
      return Permission.values.firstWhere(
        (e) => e.toString().split('.').last == value,
      );
    } catch (e) {
      return null;
    }
  }

  static String _permissionToString(Permission permission) {
    return permission.toString().split('.').last;
  }

  /// Définitions de rôles par défaut
  static RoleDefinition get defaultUserRole => RoleDefinition(
        id: 'user',
        name: 'Utilisateur',
        description: 'Utilisateur standard avec permissions de base',
        roleType: UserRoleType.user,
        priority: 10,
        permissions: [
          Permission.readPublicContent,
          Permission.createAccount,
          Permission.updateOwnProfile,
          Permission.createOrder,
          Permission.viewOwnOrders,
          Permission.manageCart,
          Permission.manageFavorites,
          Permission.followGroups,
        ],
        createdAt: DateTime.now(),
      );

  static RoleDefinition get defaultTrackerRole => RoleDefinition(
        id: 'tracker',
        name: 'Traceur',
        description: 'Utilisateur avec permissions de suivi de localisation',
        roleType: UserRoleType.tracker,
        priority: 20,
        permissions: [
          // Toutes les permissions user
          ...defaultUserRole.permissions,
          // Plus les permissions tracker
          Permission.updateLocation,
          Permission.viewTracking,
        ],
        createdAt: DateTime.now(),
      );

  static RoleDefinition get defaultGroupRole => RoleDefinition(
        id: 'group',
        name: 'Administrateur de groupe',
        description: 'Gestion complète d\'un groupe spécifique',
        roleType: UserRoleType.group,
        priority: 50,
        permissions: [
          // Toutes les permissions user
          ...defaultUserRole.permissions,
          // Permissions groupe
          Permission.manageGroupInfo,
          Permission.manageGroupProducts,
          Permission.viewGroupOrders,
          Permission.viewGroupStats,
          Permission.manageGroupMembers,
        ],
        createdAt: DateTime.now(),
      );

  static RoleDefinition get defaultAdminRole => RoleDefinition(
        id: 'admin',
        name: 'Administrateur',
        description: 'Administrateur avec accès complet au système',
        roleType: UserRoleType.admin,
        priority: 90,
        permissions: [
          // Toutes les permissions de base
          ...defaultUserRole.permissions,
          // Permissions admin
          Permission.manageAllGroups,
          Permission.manageAllUsers,
          Permission.manageAllProducts,
          Permission.manageAllOrders,
          Permission.managePlaces,
          Permission.managePOIs,
          Permission.manageCircuits,
          Permission.viewAllStats,
          Permission.moderateContent,
        ],
        createdAt: DateTime.now(),
      );

  static RoleDefinition get defaultSuperAdminRole => RoleDefinition(
        id: 'superAdmin',
        name: 'Super Administrateur',
        description: 'Tous les droits sur le système',
        roleType: UserRoleType.superAdmin,
        priority: 100,
        permissions: Permission.values, // Toutes les permissions
        createdAt: DateTime.now(),
      );

  /// Obtenir toutes les définitions par défaut
  static List<RoleDefinition> get defaultRoles => [
        defaultUserRole,
        defaultTrackerRole,
        defaultGroupRole,
        defaultAdminRole,
        defaultSuperAdminRole,
      ];

  /// Convertir une chaîne de rôle en enum
  static UserRoleType roleFromString(String role) {
    return _parseRoleType(role);
  }

  /// Convertir un enum de rôle en clé string
  static String roleToString(UserRoleType role) {
    return _roleTypeToString(role);
  }

  /// Obtenir le label d'affichage pour un rôle
  static String getRoleLabel(UserRoleType role) {
    switch (role) {
      case UserRoleType.user:
        return 'Utilisateur';
      case UserRoleType.tracker:
        return 'Traceur';
      case UserRoleType.group:
        return 'Groupe';
      case UserRoleType.admin:
        return 'Administrateur';
      case UserRoleType.superAdmin:
        return 'Super Admin';
    }
  }

  /// Obtenir le label à partir d'une clé string
  static String getRoleLabelFromString(String role) {
    return getRoleLabel(roleFromString(role));
  }
}

/// Extension pour UserProfile avec permissions
extension UserProfilePermissions on Permission {
  String get displayName {
    switch (this) {
      case Permission.readPublicContent:
        return 'Lire le contenu public';
      case Permission.createAccount:
        return 'Créer un compte';
      case Permission.updateOwnProfile:
        return 'Modifier son profil';
      case Permission.createOrder:
        return 'Créer des commandes';
      case Permission.viewOwnOrders:
        return 'Voir ses commandes';
      case Permission.manageCart:
        return 'Gérer son panier';
      case Permission.manageFavorites:
        return 'Gérer ses favoris';
      case Permission.followGroups:
        return 'Suivre des groupes';
      case Permission.updateLocation:
        return 'Mettre à jour sa localisation';
      case Permission.viewTracking:
        return 'Voir le suivi';
      case Permission.manageGroupInfo:
        return 'Gérer les infos du groupe';
      case Permission.manageGroupProducts:
        return 'Gérer les produits du groupe';
      case Permission.viewGroupOrders:
        return 'Voir les commandes du groupe';
      case Permission.viewGroupStats:
        return 'Voir les stats du groupe';
      case Permission.manageGroupMembers:
        return 'Gérer les membres du groupe';
      case Permission.manageAllGroups:
        return 'Gérer tous les groupes';
      case Permission.manageAllUsers:
        return 'Gérer tous les utilisateurs';
      case Permission.manageAllProducts:
        return 'Gérer tous les produits';
      case Permission.manageAllOrders:
        return 'Gérer toutes les commandes';
      case Permission.managePlaces:
        return 'Gérer les lieux';
      case Permission.managePOIs:
        return 'Gérer les POIs';
      case Permission.manageCircuits:
        return 'Gérer les circuits';
      case Permission.viewAllStats:
        return 'Voir toutes les statistiques';
      case Permission.moderateContent:
        return 'Modérer le contenu';
      case Permission.manageRoles:
        return 'Gérer les rôles';
      case Permission.managePermissions:
        return 'Gérer les permissions';
      case Permission.accessAdminPanel:
        return 'Accès au panneau admin';
      case Permission.deleteAnyContent:
        return 'Supprimer n\'importe quel contenu';
    }
  }

  String get category {
    if ([
      Permission.readPublicContent,
      Permission.createAccount,
      Permission.updateOwnProfile
    ].contains(this)) {
      return 'Base';
    }
    if ([
      Permission.createOrder,
      Permission.viewOwnOrders,
      Permission.manageCart,
      Permission.manageFavorites,
      Permission.followGroups
    ].contains(this)) {
      return 'Utilisateur';
    }
    if ([Permission.updateLocation, Permission.viewTracking].contains(this)) {
      return 'Traceur';
    }
    if ([
      Permission.manageGroupInfo,
      Permission.manageGroupProducts,
      Permission.viewGroupOrders,
      Permission.viewGroupStats,
      Permission.manageGroupMembers
    ].contains(this)) {
      return 'Groupe';
    }
    if ([
      Permission.manageAllGroups,
      Permission.manageAllUsers,
      Permission.manageAllProducts,
      Permission.manageAllOrders,
      Permission.managePlaces,
      Permission.managePOIs,
      Permission.manageCircuits,
      Permission.viewAllStats,
      Permission.moderateContent
    ].contains(this)) {
      return 'Administrateur';
    }
    return 'Super Admin';
  }
}
