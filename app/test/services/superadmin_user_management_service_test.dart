import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/services/superadmin_user_management_service.dart';

void main() {
  test('ManagedUserAccount lit un Admin Groupe', () {
    final user = ManagedUserAccount.fromMap(<String, dynamic>{
      'uid': 'user-1',
      'email': 'user@example.com',
      'displayName': 'Utilisateur Test',
      'role': 'group',
      'isActive': true,
      'adminGroupId': '123456',
      'emailVerified': true,
    });

    expect(user.uid, 'user-1');
    expect(user.isGroupAdmin, isTrue);
    expect(user.adminGroupId, '123456');
    expect(user.emailVerified, isTrue);
  });

  test('ManagedUserAccount accepte les champs absents', () {
    final user = ManagedUserAccount.fromMap(<String, dynamic>{});

    expect(user.uid, isEmpty);
    expect(user.role, 'user');
    expect(user.isActive, isTrue);
    expect(user.adminGroupId, isNull);
  });

  test('ManagedUserMutationResult lit le QR et les Trackers migrés', () {
    final result = ManagedUserMutationResult.fromMap(<String, dynamic>{
      'uid': 'group-admin-1',
      'role': 'group',
      'adminGroupId': '654321',
      'qrPayload': 'maslive_group_654321',
      'migratedTrackers': 5,
    });

    expect(result.adminGroupId, '654321');
    expect(result.qrPayload, contains('654321'));
    expect(result.migratedTrackers, 5);
  });
}
