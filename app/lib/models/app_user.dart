import 'package:cloud_firestore/cloud_firestore.dart';

import '../security/role_normalizer.dart';

/// Modèle utilisateur complet de l'application.
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

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser.fromMap(doc.id, data);
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final isAdmin = data['isAdmin'] as bool? ?? false;
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
      region: data['region'] as String?,
      role: RoleNormalizer.normalize(data['role'] as String?, isAdminFlag: isAdmin),
      groupId: data['groupId'] as String?,
      isAdmin: isAdmin,
      isActive: data['isActive'] as bool? ?? true,
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      fcmTokens: (data['fcmTokens'] as List<dynamic>?)?.cast<String>(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

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
    final nextIsAdmin = isAdmin ?? this.isAdmin;
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      region: region ?? this.region,
      role: RoleNormalizer.normalize(role ?? this.role, isAdminFlag: nextIsAdmin),
      groupId: groupId ?? this.groupId,
      isAdmin: nextIsAdmin,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      metadata: metadata ?? this.metadata,
    );
  }

  String get canonicalRole => RoleNormalizer.normalize(role, isAdminFlag: isAdmin);

  bool get isSuperAdmin => canonicalRole == RoleNormalizer.superAdmin;

  bool get isAdminRole =>
      canonicalRole == RoleNormalizer.admin || canonicalRole == RoleNormalizer.superAdmin;

  bool get isGroupAdmin => canonicalRole == RoleNormalizer.group && groupId != null;

  bool get isTracker => canonicalRole == RoleNormalizer.tracker || isGroupAdmin;

  String get displayNameOrEmail => displayName ?? email.split('@').first;

  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  String get roleLabel => RoleNormalizer.label(canonicalRole);

  @override
  String toString() => 'AppUser($uid, $email, $canonicalRole)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppUser && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
