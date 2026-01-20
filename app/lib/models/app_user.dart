import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle utilisateur complet de l'application
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phone;
  final String? region;
  final String role;
  final String? groupId;
  final bool isAdmin;
  final bool isActive;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? fcmTokens;
  final Map<String, dynamic>? metadata;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.phone,
    this.region,
    this.role = 'user',
    this.groupId,
    this.isAdmin = false,
    this.isActive = true,
    this.isEmailVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.fcmTokens,
    this.metadata,
  });

  /// Créer depuis Firestore
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser.fromMap(doc.id, data);
  }

  /// Créer depuis Map
  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
      region: data['region'] as String?,
      role: data['role'] as String? ?? 'user',
      groupId: data['groupId'] as String?,
      isAdmin: data['isAdmin'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      fcmTokens: (data['fcmTokens'] as List<dynamic>?)?.cast<String>(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phone': phone,
      'region': region,
      'role': role,
      'groupId': groupId,
      'isAdmin': isAdmin,
      'isActive': isActive,
      'isEmailVerified': isEmailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'fcmTokens': fcmTokens,
      'metadata': metadata,
    };
  }

  /// Copie avec modifications
  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? phone,
    String? region,
    String? role,
    String? groupId,
    bool? isAdmin,
    bool? isActive,
    bool? isEmailVerified,
    DateTime? updatedAt,
    List<String>? fcmTokens,
    Map<String, dynamic>? metadata,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      region: region ?? this.region,
      role: role ?? this.role,
      groupId: groupId ?? this.groupId,
      isAdmin: isAdmin ?? this.isAdmin,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Vérifier si l'utilisateur est super admin
  bool get isSuperAdmin => role == 'superAdmin';

  /// Vérifier si l'utilisateur est admin (incluant super admin)
  bool get isAdminRole => isAdmin || role == 'admin' || role == 'superAdmin';

  /// Vérifier si l'utilisateur est admin de groupe
  bool get isGroupAdmin => role == 'group' && groupId != null;

  /// Vérifier si l'utilisateur est traceur
  bool get isTracker => role == 'tracker' || isGroupAdmin;

  /// Obtenir le nom affiché
  String get displayNameOrEmail => displayName ?? email.split('@').first;

  /// Obtenir les initiales
  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    return email[0].toUpperCase();
  }

  /// Obtenir le label du rôle
  String get roleLabel {
    switch (role) {
      case 'superAdmin':
        return 'Super Administrateur';
      case 'admin':
        return 'Administrateur';
      case 'group':
        return 'Admin Groupe';
      case 'tracker':
        return 'Traceur';
      case 'user':
      default:
        return 'Utilisateur';
    }
  }

  @override
  String toString() => 'AppUser($uid, $email, $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
