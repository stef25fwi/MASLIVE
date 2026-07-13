import 'package:cloud_functions/cloud_functions.dart';

class ManagedUserAccount {
  const ManagedUserAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.isAdmin,
    required this.adminGroupId,
    required this.emailVerified,
    required this.createdAt,
    required this.lastSignInAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final String role;
  final bool isActive;
  final bool isAdmin;
  final String? adminGroupId;
  final bool emailVerified;
  final String? createdAt;
  final String? lastSignInAt;

  bool get isGroupAdmin => role == 'group';
  bool get isTracker => role == 'tracker';

  factory ManagedUserAccount.fromMap(Map<String, dynamic> map) {
    String? nullableString(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return ManagedUserAccount(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      role: map['role']?.toString() ?? 'user',
      isActive: map['isActive'] != false,
      isAdmin: map['isAdmin'] == true,
      adminGroupId: nullableString(map['adminGroupId']),
      emailVerified: map['emailVerified'] == true,
      createdAt: nullableString(map['createdAt']),
      lastSignInAt: nullableString(map['lastSignInAt']),
    );
  }
}

class ManagedUserMutationResult {
  const ManagedUserMutationResult({
    required this.uid,
    required this.role,
    required this.adminGroupId,
    required this.qrPayload,
    this.email,
    this.displayName,
    this.oldCode,
    this.migratedTrackers,
  });

  final String uid;
  final String role;
  final String? email;
  final String? displayName;
  final String? adminGroupId;
  final String? qrPayload;
  final String? oldCode;
  final int? migratedTrackers;

  factory ManagedUserMutationResult.fromMap(Map<String, dynamic> map) {
    String? nullableString(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return ManagedUserMutationResult(
      uid: map['uid']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      email: nullableString(map['email']),
      displayName: nullableString(map['displayName']),
      adminGroupId: nullableString(map['adminGroupId']),
      qrPayload: nullableString(map['qrPayload']),
      oldCode: nullableString(map['oldCode']),
      migratedTrackers: map['migratedTrackers'] is num
          ? (map['migratedTrackers'] as num).toInt()
          : null,
    );
  }
}

class ManagedUsersSearchResult {
  const ManagedUsersSearchResult({
    required this.users,
    required this.truncated,
  });

  final List<ManagedUserAccount> users;
  final bool truncated;
}

class SuperAdminUserManagementException implements Exception {
  const SuperAdminUserManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SuperAdminUserManagementService {
  SuperAdminUserManagementService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFunctions _functions;

  Future<ManagedUsersSearchResult> searchUsers(String query) async {
    final data = await _call('searchManagedUsers', <String, dynamic>{
      'query': query.trim(),
    });
    final rawUsers = data['users'];
    final users = rawUsers is List
        ? rawUsers
              .whereType<Map>()
              .map(
                (entry) => ManagedUserAccount.fromMap(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList(growable: false)
        : const <ManagedUserAccount>[];
    return ManagedUsersSearchResult(
      users: users,
      truncated: data['truncated'] == true,
    );
  }

  Future<ManagedUserMutationResult> createUser({
    required String email,
    required String password,
    required String displayName,
    required String role,
    String? adminGroupId,
  }) async {
    final data = await _call('createManagedUser', <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'displayName': displayName.trim(),
      'role': role,
      'adminGroupId': adminGroupId?.trim(),
    });
    return ManagedUserMutationResult.fromMap(data);
  }

  Future<ManagedUserMutationResult> updateUser({
    required String uid,
    required String email,
    required String displayName,
    required String role,
    required bool isActive,
    String? password,
    String? adminGroupId,
  }) async {
    final data = await _call('updateManagedUser', <String, dynamic>{
      'uid': uid,
      'email': email.trim(),
      'displayName': displayName.trim(),
      'role': role,
      'isActive': isActive,
      'password': password?.trim(),
      'adminGroupId': adminGroupId?.trim(),
    });
    return ManagedUserMutationResult.fromMap(data);
  }

  Future<ManagedUserMutationResult> regenerateGroupCode(String uid) async {
    final data = await _call(
      'regenerateManagedGroupCode',
      <String, dynamic>{'uid': uid},
    );
    return ManagedUserMutationResult.fromMap(data);
  }

  Future<int> deleteUser(String uid) async {
    final data = await _call(
      'deleteManagedUser',
      <String, dynamic>{'uid': uid},
    );
    final detached = data['detachedTrackers'];
    return detached is num ? detached.toInt() : 0;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(payload);
      final value = result.data;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      throw const SuperAdminUserManagementException(
        'Réponse serveur invalide.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw SuperAdminUserManagementException(
        error.message ?? 'Opération impossible.',
      );
    } on SuperAdminUserManagementException {
      rethrow;
    } catch (error) {
      throw SuperAdminUserManagementException(
        'Erreur de communication : $error',
      );
    }
  }
}
