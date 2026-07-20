import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'role_normalizer.dart';

enum ProfileKind {
  user,
  artisanArt,
  creatorDigital,
  tracker,
  groupAdmin,
  admin,
  superAdmin,
}

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
  manageArtGallery,
  submitArtwork,
  receiveArtOffers,
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
    required this.activeKinds,
    required this.canonicalRole,
    required this.groupId,
    required this.adminGroupId,
    required this.hasBusiness,
    required this.hasBloomArtSellerProfile,
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

  /// Profil principal utilisé uniquement pour le libellé et l'ordre de
  /// présentation. Les autorisations proviennent de [activeKinds] cumulés.
  final ProfileKind kind;
  final Set<ProfileKind> activeKinds;
  final String canonicalRole;
  final String? groupId;
  final String? adminGroupId;

  /// Le profil générique « Compte Pro » est retiré. Les vendeurs utilisent les
  /// espaces métier Artisan d'art, Créateur digital ou Admin Groupe.
  final bool hasBusiness;
  final bool hasBloomArtSellerProfile;
  final bool hasPhotographerProfile;
  final String? groupAdminRequestStatus;
  final Set<Capability> capabilities;
  final Map<String, dynamic> rawUserData;

  bool can(Capability capability) => isActive && capabilities.contains(capability);
  bool hasKind(ProfileKind value) => activeKinds.contains(value);

  bool get canSubmitCommerce =>
      can(Capability.submitProduct) ||
      can(Capability.submitMedia) ||
      can(Capability.submitArtwork);

  bool get canManageSellerInbox =>
      can(Capability.manageOwnGallery) ||
      can(Capability.manageArtGallery) ||
      can(Capability.manageGroupShop) ||
      can(Capability.manageAllOrders);

  bool get hasPendingGroupAdminRequest => groupAdminRequestStatus == 'pending';
  bool get hasRejectedGroupAdminRequest => groupAdminRequestStatus == 'rejected';

  String get roleLabel => labelFor(kind);

  List<String> get activeRoleLabels {
    const order = <ProfileKind>[
      ProfileKind.superAdmin,
      ProfileKind.admin,
      ProfileKind.groupAdmin,
      ProfileKind.tracker,
      ProfileKind.artisanArt,
      ProfileKind.creatorDigital,
      ProfileKind.user,
    ];
    return order.where(activeKinds.contains).map(labelFor).toList(growable: false);
  }

  static String labelFor(ProfileKind value) {
    switch (value) {
      case ProfileKind.superAdmin:
        return 'SuperAdmin';
      case ProfileKind.admin:
        return 'Admin MASLIVE';
      case ProfileKind.groupAdmin:
        return 'Admin Groupe';
      case ProfileKind.tracker:
        return 'Tracker Groupe';
      case ProfileKind.artisanArt:
        return 'Artisan d’art';
      case ProfileKind.creatorDigital:
        return 'Créateur digital';
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
    return resolve(
      user.uid,
      fallbackEmail: user.email,
      fallbackName: user.displayName,
      fallbackPhotoUrl: user.photoURL,
    );
  }

  Future<ProfileCapabilities?> resolve(
    String uid, {
    String? fallbackEmail,
    String? fallbackName,
    String? fallbackPhotoUrl,
  }) async {
    final results = await Future.wait(<Future<dynamic>>[
      _firestore.collection('users').doc(uid).get(),
      _firestore
          .collection('photographers')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get(),
      _firestore.collection('bloom_art_seller_profiles').doc(uid).get(),
      _firestore.collection('group_admins').doc(uid).get(),
      _firestore.collection('group_trackers').doc(uid).get(),
      _firestore.collection('group_admin_requests').doc(uid).get(),
    ]);

    final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final photographerSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final bloomArtSellerDoc =
        results[2] as DocumentSnapshot<Map<String, dynamic>>;
    final groupAdminDoc = results[3] as DocumentSnapshot<Map<String, dynamic>>;
    final trackerDoc = results[4] as DocumentSnapshot<Map<String, dynamic>>;
    final groupRequestDoc = results[5] as DocumentSnapshot<Map<String, dynamic>>;

    final userData = userDoc.data() ?? <String, dynamic>{};
    final isAdminFlag = userData['isAdmin'] == true;
    final canonicalRole = RoleNormalizer.normalize(
      userData['role'] as String?,
      isAdminFlag: isAdminFlag,
    );
    final activities = (userData['activities'] as List<dynamic>?)
            ?.map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet() ??
        const <String>{};

    final hasPhotographerProfile = photographerSnap.docs.isNotEmpty;
    final bloomArtSellerData = bloomArtSellerDoc.data();
    final bloomArtProfileType =
        (bloomArtSellerData?['profileType'] as String?)?.trim();
    final hasBloomArtSellerProfile = bloomArtSellerDoc.exists &&
        (bloomArtProfileType == null ||
            bloomArtProfileType.isEmpty ||
            bloomArtProfileType == 'artisan_art' ||
            bloomArtProfileType == 'artist_creator');

    final groupAdminData = groupAdminDoc.data();
    final trackerData = trackerDoc.data();
    final requestData = groupRequestDoc.data();
    final adminGroupId =
        (groupAdminData?['adminGroupId'] ?? trackerData?['adminGroupId'])
            as String?;

    final activeKinds = _resolveActiveKinds(
      canonicalRole: canonicalRole,
      activities: activities,
      hasBloomArtSellerProfile: hasBloomArtSellerProfile,
      hasPhotographerProfile: hasPhotographerProfile,
      hasGroupAdminProfile: groupAdminDoc.exists,
      hasTrackerProfile: trackerDoc.exists,
    );
    final primaryKind = _primaryKind(activeKinds);

    return ProfileCapabilities(
      uid: uid,
      email: (userData['email'] as String?) ?? fallbackEmail ?? '',
      displayName: ((userData['displayName'] as String?) ??
              fallbackName ??
              fallbackEmail ??
              'Utilisateur')
          .trim(),
      photoUrl: (userData['photoUrl'] as String?) ?? fallbackPhotoUrl,
      isActive: userData['isActive'] as bool? ?? true,
      kind: primaryKind,
      activeKinds: Set<ProfileKind>.unmodifiable(activeKinds),
      canonicalRole: canonicalRole,
      groupId: userData['groupId'] as String?,
      adminGroupId: adminGroupId,
      hasBusiness: false,
      hasBloomArtSellerProfile: hasBloomArtSellerProfile,
      hasPhotographerProfile: hasPhotographerProfile,
      groupAdminRequestStatus: requestData?['status'] as String?,
      capabilities: Set<Capability>.unmodifiable(
        _capabilitiesForAll(activeKinds),
      ),
      rawUserData: userData,
    );
  }

  Set<ProfileKind> _resolveActiveKinds({
    required String canonicalRole,
    required Set<String> activities,
    required bool hasBloomArtSellerProfile,
    required bool hasPhotographerProfile,
    required bool hasGroupAdminProfile,
    required bool hasTrackerProfile,
  }) {
    final kinds = <ProfileKind>{ProfileKind.user};

    if (canonicalRole == RoleNormalizer.superAdmin) {
      kinds.add(ProfileKind.superAdmin);
    } else if (canonicalRole == RoleNormalizer.admin) {
      kinds.add(ProfileKind.admin);
    }

    if (canonicalRole == RoleNormalizer.group || hasGroupAdminProfile) {
      kinds.add(ProfileKind.groupAdmin);
    }
    if (canonicalRole == RoleNormalizer.tracker || hasTrackerProfile) {
      kinds.add(ProfileKind.tracker);
    }
    if (hasBloomArtSellerProfile || activities.contains('artisan_art')) {
      kinds.add(ProfileKind.artisanArt);
    }
    if (hasPhotographerProfile ||
        activities.contains('createur_digital') ||
        activities.contains('creator_digital')) {
      kinds.add(ProfileKind.creatorDigital);
    }

    return kinds;
  }

  ProfileKind _primaryKind(Set<ProfileKind> kinds) {
    const priority = <ProfileKind>[
      ProfileKind.superAdmin,
      ProfileKind.admin,
      ProfileKind.groupAdmin,
      ProfileKind.tracker,
      ProfileKind.artisanArt,
      ProfileKind.creatorDigital,
      ProfileKind.user,
    ];
    return priority.firstWhere(kinds.contains);
  }

  Set<Capability> _capabilitiesForAll(Set<ProfileKind> kinds) {
    if (kinds.contains(ProfileKind.superAdmin)) {
      return Capability.values.toSet();
    }

    final result = <Capability>{};
    for (final kind in kinds) {
      result.addAll(_capabilitiesFor(kind));
    }
    return result;
  }

  Set<Capability> _capabilitiesFor(ProfileKind kind) {
    const base = <Capability>{
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

    switch (kind) {
      case ProfileKind.user:
        return base;
      case ProfileKind.creatorDigital:
        return <Capability>{
          ...base,
          Capability.submitMedia,
          Capability.manageOwnGallery,
        };
      case ProfileKind.artisanArt:
        return <Capability>{
          ...base,
          Capability.manageArtGallery,
          Capability.submitArtwork,
          Capability.receiveArtOffers,
        };
      case ProfileKind.tracker:
        return <Capability>{
          ...base,
          Capability.trackOwnLocation,
          Capability.viewOwnTrackHistory,
          Capability.exportOwnTracks,
        };
      case ProfileKind.groupAdmin:
        return <Capability>{
          ...base,
          Capability.trackOwnLocation,
          Capability.viewOwnTrackHistory,
          Capability.exportOwnTracks,
          Capability.viewGroupLiveMap,
          Capability.manageGroupMembers,
          Capability.manageGroupShop,
          Capability.manageGroupTracking,
          Capability.viewGroupStats,
          Capability.submitProduct,
          Capability.submitMedia,
        };
      case ProfileKind.admin:
        return <Capability>{
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
      case ProfileKind.superAdmin:
        return Capability.values.toSet();
    }
  }
}
