/// Normalise les anciens alias de rôles vers les rôles canoniques MASLIVE.
///
/// Rôles canoniques conservés en base :
/// - user
/// - tracker
/// - group
/// - admin
/// - superAdmin
class RoleNormalizer {
  const RoleNormalizer._();

  static const String user = 'user';
  static const String tracker = 'tracker';
  static const String group = 'group';
  static const String admin = 'admin';
  static const String superAdmin = 'superAdmin';

  static String normalize(String? rawRole, {bool isAdminFlag = false}) {
    final role = (rawRole ?? '').trim();
    final lower = role.toLowerCase().replaceAll(' ', '').replaceAll('-', '_');

    if (lower == 'superadmin' || lower == 'super_admin') {
      return superAdmin;
    }
    if (lower == 'admin' || lower == 'admin_master' || lower == 'masteradmin') {
      return admin;
    }
    if (lower == 'group' ||
        lower == 'group_admin' ||
        lower == 'admingroup' ||
        lower == 'admin_group' ||
        lower == 'admin_groupe') {
      return group;
    }
    if (lower == 'tracker' || lower == 'tracker_group' || lower == 'tracker_groupe') {
      return tracker;
    }
    if (isAdminFlag) {
      // Compatibilité historique : anciens comptes avec isAdmin=true mais sans rôle.
      return admin;
    }
    return user;
  }

  static bool isSuperAdmin(String? rawRole, {bool isAdminFlag = false}) {
    return normalize(rawRole, isAdminFlag: isAdminFlag) == superAdmin;
  }

  static bool isMasterAdmin(String? rawRole, {bool isAdminFlag = false}) {
    final normalized = normalize(rawRole, isAdminFlag: isAdminFlag);
    return normalized == admin || normalized == superAdmin;
  }

  static bool isGroupAdmin(String? rawRole, {bool isAdminFlag = false}) {
    return normalize(rawRole, isAdminFlag: isAdminFlag) == group;
  }

  static bool isTracker(String? rawRole, {bool isAdminFlag = false}) {
    return normalize(rawRole, isAdminFlag: isAdminFlag) == tracker;
  }

  static String label(String normalizedRole) {
    switch (normalizedRole) {
      case superAdmin:
        return 'Super Administrateur';
      case admin:
        return 'Administrateur MASLIVE';
      case group:
        return 'Administrateur Groupe';
      case tracker:
        return 'Tracker Groupe';
      case user:
      default:
        return 'Utilisateur';
    }
  }
}
