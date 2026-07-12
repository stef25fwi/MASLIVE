import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'role_normalizer.dart';

/// Profils fonctionnels affichés dans l'application.
enum ProfileKind {
  user,
  pro,
  creatorDigital,
  photographer,
  tracker,
  groupAdmin,
  admin,
  superAdmin,
}

/// Capacités métier réellement utilisables dans l'UI et les guards.
enum Capability {
  viewProfile,
  editOwnProfile,
  manageFavorites,
  buyProducts,
  viewCart,
  viewOwnOrders,
  downloadPurchases,
  manageAlerts,
  manageOwnBusiness,
  submitProduct,
  submitMedia,
  manageOwnGallery,
  trackOwnLocation,
  viewOwnTrackHistory,
  exportOwnTracks,
  viewGroupLiveMap,
  manageGroupMembers,
  manageGroupShop,
  manageGroupTracking,
  viewGroupStats,
  requestGroupAdmin,
  moderateCommerce,
  accessAdminPanel,
  manageAllUsers,
  manageAllGroups,
  manageAllProducts,
  manageAllOrders,
  managePlaces,
  managePOIs,
  manageCircuits,
  viewAllStats,
  manageRoles,
  managePermissions,
  deleteAnyContent,
}

class ProfileCapabilities {
  const ProfileCapabilities({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.isActive,
    required this.kind,
    required this.canonicalRole,
    required this.groupId,
    required this.adminGroupId,
    required this.hasBusiness,
    required this.hasPhotographerProfile,
    required this.groupAdminRequestStatus,
    required this.capabilities,
    required this.rawUserData,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isActive;
  final ProfileKind kind;
  final String canonicalRole;
  final String? groupId;
  final String? adminGroupId;
  final bool hasBusiness;
  final bool hasPhotographerProfile;
  final String? groupAdminRequestStatus;
  final Set<Capability> capabilities;
  final Map<String, dynamic> rawUserData;

  bool can(Capability capability) => capabilities.contains(capability);

  bool get canSubmitCommerce =>
      can(Capability.submitProduct) || can(Capability.submitMedia);

  bool get hasPendingGroupAdminRequest => groupAdminRequestStatus == 'pending';

  String get roleLabel {
    switch (kind) {
      case ProfileKind.superAdmin:
        return 'SuperAdmin';
      case ProfileKind.admin:
        return 'Admin MASLIVE';
      case ProfileKind.groupAdmin:
        return 'Admin Groupe';
      case ProfileKind.tracker:
        return 'Tracker Groupe';
      case ProfileKind.photographer:
        return 'Photographe';
      case ProfileKind.creatorDigital:
        return 'Créateur digital';
      case ProfileKind.pro:
        return 'Compte Pro';
      case ProfileKind.user:
        return 'Utilisateur';
    }
  }
}

class ProfileCapabilityPolicy {
  ProfileCapabilityPolicy._();
  static final ProfileCapabilityPolicy instance = ProfileCapabilityPolicy._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<ProfileCapabilities?> resolveCurrent() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return resolve(user.uid, fallbackEmail: user.email, fallbackName: user.displayName, fallbackPhotoUrl: user.photoURL);
  }

  Future<ProfileCapabilities?> resolve(
    String uid, {
    String? fallbackEmail,
    String? fallbackName,
    String? fallbackPhotoUrl,
  }) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    final isAdminFlag = userData['isAdmin'] == true;
    final canonicalRole = RoleNormalizer.normalize(
      userData['role'] as String?,
      isAdminFlag: isAdminFlag,
    );

    final businessDoc = await _firestore.collection('businesses').doc(uid).get();
    final hasBusiness = businessDoc.exists;
    final accountType = (userData['accountType'] as String?)?.trim().toLowerCase();
    final activities = (userData['activities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        const <String>{};

    final photographerSnap = await _firestore
        .collection('photographers')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();
    final hasPhotographerProfile = photographerSnap.docs.isNotEmpty;

    final groupAdminDoc = await _firestore.collection('group_admins').doc(uid).get();
    final trackerDoc = await _firestore.collection('group_trackers').doc(uid).get();
    final groupRequestDoc = await _firestore.collection('group_admin_requests').doc(uid).get();

    final groupAdminData = groupAdminDoc.data();
    final trackerData = trackerDoc.data();
    final requestData = groupRequestDoc.data();
    final adminGroupId = (groupAdminData?['adminGroupId'] ?? trackerData?['adminGroupId']) as String?;

    final kind = _resolveKind(
      canonicalRole: canonicalRole,
      accountType: accountType,
      activities: activities,
      hasBusiness: hasBusiness,
      hasPhotographerProfile: hasPhotographerProfile,
      hasGroupAdminProfile: groupAdminDoc.exists,
      hasTrackerProfile: trackerDoc.exists,
    );

    return ProfileCapabilities(
      uid: uid,
      email: (userData['email'] as String?) ?? fallbackEmail ?? '',
      displayName: ((userData['displayName'] as String?) ?? fallbackName ?? fallbackEmail ?? 'Utilisateur').trim(),
      photoUrl: (userData['photoUrl'] as String?) ?? fallbackPhotoUrl,
      isActive: userData['isActive'] as bool? ?? true,
      kind: kind,
      canonicalRole: canonicalRole,
      groupId: userData['groupId'] as String?,
      adminGroupId: adminGroupId,
      hasBusiness: hasBusiness,
      hasPhotographerProfile: hasPhotographerProfile,
      groupAdminRequestStatus: requestData?['status'] as String?,
      capabilities: _capabilitiesFor(kind),
      rawUserData: userData,
    );
  }

  ProfileKind _resolveKind({
    required String canonicalRole,
    required String? accountType,
    required Set<String> activities,
    required bool hasBusiness,
    required bool hasPhotographerProfile,
    required bool hasGroupAdminProfile,
    required bool hasTrackerProfile,
  }) {
    if (canonicalRole == RoleNormalizer.superAdmin) return ProfileKind.superAdmin;
    if (canonicalRole == RoleNormalizer.admin) return ProfileKind.admin;
    if (canonicalRole == RoleNormalizer.group || hasGroupAdminProfile) {
      return ProfileKind.groupAdmin;
    }
    if (canonicalRole == RoleNormalizer.tracker || hasTrackerProfile) {
      return ProfileKind.tracker;
    }
    if (hasPhotographerProfile) return ProfileKind.photographer;
    if (activities.contains('createur_digital') || activities.contains('creator_digital')) {
      return ProfileKind.creatorDigital;
    }
    if (accountType == 'pro' || hasBusiness) return ProfileKind.pro;
    return ProfileKind.user;
  }

  Set<Capability> _capabilitiesFor(ProfileKind kind) {
    final base = <Capability>{
      Capability.viewProfile,
      Capability.editOwnProfile,
      Capability.manageFavorites,
      Capability.buyProducts,
      Capability.viewCart,
      Capability.viewOwnOrders,
      Capability.downloadPurchases,
      Capability.manageAlerts,
      Capability.requestGroupAdmin,
    };

    final pro = <Capability>{
      ...base,
      Capability.manageOwnBusiness,
      Capability.submitProduct,
    };

    final creator = <Capability>{
      ...pro,
      Capability.submitMedia,
      Capability.manageOwnGallery,
    };

    final tracker = <Capability>{
      ...base,
      Capability.trackOwnLocation,
      Capability.viewOwnTrackHistory,
      Capability.exportOwnTracks,
      Capability.viewGroupLiveMap,
    };

    final groupAdmin = <Capability>{
      ...tracker,
      Capability.manageGroupMembers,
      Capability.manageGroupShop,
      Capability.manageGroupTracking,
      Capability.viewGroupStats,
      Capability.submitProduct,
      Capability.submitMedia,
    };

    final admin = <Capability>{
      ...base,
      Capability.moderateCommerce,
      Capability.accessAdminPanel,
      Capability.manageAllUsers,
      Capability.manageAllGroups,
      Capability.manageAllProducts,
      Capability.manageAllOrders,
      Capability.managePlaces,
      Capability.managePOIs,
      Capability.manageCircuits,
      Capability.viewAllStats,
    };

    switch (kind) {
      case ProfileKind.superAdmin:
        return Capability.values.toSet();
      case ProfileKind.admin:
        return admin;
      case ProfileKind.groupAdmin:
        return groupAdmin;
      case ProfileKind.tracker:
        return tracker;
      case ProfileKind.photographer:
      case ProfileKind.creatorDigital:
        return creator;
      case ProfileKind.pro:
        return pro;
      case ProfileKind.user:
        return base;
    }
  }
}
