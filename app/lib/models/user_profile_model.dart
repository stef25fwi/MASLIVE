import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, group, admin }

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

  // Convertir depuis Firestore document
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final created = data['createdAt'] as Timestamp?;
    return UserProfile(
      id: doc.id,
      email: data['email'] as String,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
      region: data['region'] as String?,
      groupId: data['groupId'] as String?,
      role: parseRole(data['role'] as String?),
      createdAt: created != null ? created.toDate() : DateTime.now(),
      isAdmin: data['isAdmin'] as bool? ?? false,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phone': phone,
      'region': region,
      'groupId': groupId,
      'role': roleToString(role),
      'createdAt': createdAt,
      'isAdmin': isAdmin,
    };
  }

  @override
  String toString() => 'UserProfile($id, $email, $displayName)';

  static UserRole parseRole(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'group':
        return UserRole.group;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.group:
        return 'group';
      case UserRole.user:
        return 'user';
    }
  }
}
