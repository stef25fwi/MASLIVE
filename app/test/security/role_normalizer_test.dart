import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/security/role_normalizer.dart';

void main() {
  group('RoleNormalizer', () {
    test('normalise les alias super admin', () {
      expect(RoleNormalizer.normalize('superadmin'), RoleNormalizer.superAdmin);
      expect(RoleNormalizer.normalize('super-admin'), RoleNormalizer.superAdmin);
      expect(RoleNormalizer.normalize('super_admin'), RoleNormalizer.superAdmin);
      expect(RoleNormalizer.isSuperAdmin('superadmin'), isTrue);
    });

    test('normalise les alias admin groupe', () {
      expect(RoleNormalizer.normalize('admin_groupe'), RoleNormalizer.group);
      expect(RoleNormalizer.normalize('admin_group'), RoleNormalizer.group);
      expect(RoleNormalizer.normalize('group-admin'), RoleNormalizer.group);
      expect(RoleNormalizer.isGroupAdmin('admin_groupe'), isTrue);
    });

    test('normalise les alias tracker', () {
      expect(RoleNormalizer.normalize('tracker_groupe'), RoleNormalizer.tracker);
      expect(RoleNormalizer.normalize('tracker-group'), RoleNormalizer.tracker);
      expect(RoleNormalizer.isTracker('tracker_groupe'), isTrue);
    });

    test('utilise isAdmin uniquement en compatibilité admin', () {
      expect(RoleNormalizer.normalize(null, isAdminFlag: true), RoleNormalizer.admin);
      expect(RoleNormalizer.normalize('user', isAdminFlag: true), RoleNormalizer.admin);
      expect(RoleNormalizer.normalize('superAdmin', isAdminFlag: false), RoleNormalizer.superAdmin);
    });
  });
}
