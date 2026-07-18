import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'role_normalizer.dart';

/// Profils fonctionnels affichés dans l'application.
enum ProfileKind {
  user,
  artisanArt,
  creatorDigital,
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
  final ProfileKind kind;
  final String canonicalRole;
  final String? groupId;
  final String? adminGroupId;

  /// Compat données existantes : le champ reste disponible, mais le profil
  /// fonctionnel "Compte Pro" est supprimé de MASLIVE.
  final bool hasBusiness;

  /// Profil vendeur Bloom Art, exposé comme profil fonctionnel Artisan d’art.
  final bool hasBloomArtSellerProfile;

  /// Compat données existantes : les documents `photographers` restent la source
  /// métier du module médias, mais côté profil utilisateur ils sont exposés comme
  /// un profil unique "Créateur digital".
  final bool hasPhotographerProfile;
  final String? groupAdminRequestStatus;
  final Set<Capability> capabilities;
  final Map<String, dynamic> rawUserData;

  bool can(Capability capability) => capabilities.contains(capability);

  bool get canSubmitCommerce =>
      can(Capability.submitProduct) ||
      can(Capability.submitMedia) ||
      can(Capability.submitArtwork);

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
    // Ces 6 lectures ne dépendent que de `uid` (pas les unes des autres) :
    // on les lance en parallèle plutôt qu'en série pour éviter d'empiler
    // les allers-retours réseau (c'était la cause du chargement lent de la
    // page profil : jusqu'à 6x la latence réseau au lieu de 1x).
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
    final bloomArtSellerDoc = results[2] as DocumentSnapshot<Map<String, dynamic>>;
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
            ?.map((e) => e.toString())
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
    final adminGroupId = (groupAdminData?['adminGroupId'] ?? trackerData?['adminGroupId']) as String?;

    final kind = _resolveKind(
      canonicalRole: canonicalRole,
      activities: activities,
      hasBloomArtSellerProfile: hasBloomArtSellerProfile,
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
      hasBusiness: false,
      hasBloomArtSellerProfile: hasBloomArtSellerProfile,
      hasPhotographerProfile: hasPhotographerProfile,
      groupAdminRequestStatus: requestData?['status'] as String?,
      capabilities: _capabilitiesFor(kind),
      rawUserData: userData,
    );
  }

  ProfileKind _resolveKind({
    required String canonicalRole,
    required Set<String> activities,
    required bool hasBloomArtSellerProfile,
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
    if (hasBloomArtSellerProfile || activities.contains('artisan_art')) {
      return ProfileKind.artisanArt;
    }
    if (hasPhotographerProfile ||
        activities.contains('createur_digital') ||
        activities.contains('creator_digital')) {
      return ProfileKind.creatorDigital;
    }
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

    final artisanArt = <Capability>{
      ...base,
      Capability.manageArtGallery,
      Capability.submitArtwork,
      Capability.receiveArtOffers,
      Capability.viewOwnOrders,
    };

    final creator = <Capability>{
      ...base,
      Capability.submitMedia,
      Capability.manageOwnGallery,
    };

    // Le tracker ne gère rien : il envoie uniquement sa position GPS vers le
    // groupe rattaché. Le calcul de position moyenne du groupe est ensuite fait
    // par l'app/backend et représenté côté Admin Groupe.
    final tracker = <Capability>{
      ...base,
      Capability.trackOwnLocation,
      Capability.viewOwnTrackHistory,
      Capability.exportOwnTracks,
    };

    final groupAdmin = <Capability>{
      ...tracker,
      Capability.viewGroupLiveMap,
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
      case ProfileKind.artisanArt:
        return artisanArt;
      case ProfileKind.creatorDigital:
        return creator;
      case ProfileKind.user:
        return base;
    }
  }
}
