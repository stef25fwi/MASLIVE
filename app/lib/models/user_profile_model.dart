import 'package:cloud_firestore/cloud_firestore.dart';

import '../security/role_normalizer.dart';

enum UserRole { user, tracker, group, admin, superAdmin }

class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phone;
  final String? region;
  final String? groupId;
  final UserRole role;
  final DateTime createdAt;
  final bool isAdmin;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.phone,
    this.region,
    this.groupId,
    this.role = UserRole.user,
    required this.createdAt,
    this.isAdmin = false,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final created = data['createdAt'] as Timestamp?;
    final isAdmin = data['isAdmin'] as bool? ?? false;
    return UserProfile(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
      region: data['region'] as String?,
      groupId: data['groupId'] as String?,
      role: parseRole(data['role'] as String?, isAdminFlag: isAdmin),
      createdAt: created != null ? created.toDate() : DateTime.now(),
      isAdmin: isAdmin,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phone': phone,
      'region': region,
      'groupId': groupId,
      'role': roleToString(role),
      'createdAt': Timestamp.fromDate(createdAt),
      'isAdmin': isAdmin,
    };
  }

  @override
  String toString() => 'UserProfile($id, $email, $displayName, ${roleToString(role)})';

  static UserRole parseRole(String? value, {bool isAdminFlag = false}) {
    switch (RoleNormalizer.normalize(value, isAdminFlag: isAdminFlag)) {
      case RoleNormalizer.superAdmin:
        return UserRole.superAdmin;
      case RoleNormalizer.admin:
        return UserRole.admin;
      case RoleNormalizer.group:
        return UserRole.group;
      case RoleNormalizer.tracker:
        return UserRole.tracker;
      case RoleNormalizer.user:
      default:
        return UserRole.user;
    }
  }

  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return RoleNormalizer.superAdmin;
      case UserRole.admin:
        return RoleNormalizer.admin;
      case UserRole.group:
        return RoleNormalizer.group;
      case UserRole.tracker:
        return RoleNormalizer.tracker;
      case UserRole.user:
        return RoleNormalizer.user;
    }
  }
}
