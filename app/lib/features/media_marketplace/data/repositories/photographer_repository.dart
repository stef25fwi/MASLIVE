import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/enums/photographer_status.dart';
import '../models/photographer_profile_model.dart';

class PhotographerRepository {
  PhotographerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.photographers);

  Future<PhotographerProfileModel?> getByOwnerUid(String ownerUid) async {
    final snapshot = await _collection
        .where('ownerUid', isEqualTo: ownerUid)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PhotographerProfileModel.fromDocument(snapshot.docs.first);
  }

  Future<PhotographerProfileModel?> getById(String photographerId) async {
    final doc = await _collection.doc(photographerId).get();
    if (!doc.exists) return null;
    return PhotographerProfileModel.fromDocument(doc);
  }

  Future<PhotographerProfileModel?> findByQuery(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final byId = await getById(query.trim());
    if (byId != null) return byId;

    final byOwner = await getByOwnerUid(query.trim());
    if (byOwner != null) return byOwner;

    final snapshot = await _collection.limit(50).get();
    PhotographerProfileModel? containsMatch;

    for (final doc in snapshot.docs) {
      final profile = PhotographerProfileModel.fromDocument(doc);
      final brand = profile.brandName.trim().toLowerCase();
      final owner = profile.ownerUid.trim().toLowerCase();
      final id = profile.photographerId.trim().toLowerCase();

      if (brand == normalized || owner == normalized || id == normalized) {
        return profile;
      }

      if (containsMatch == null && (brand.contains(normalized) || owner.contains(normalized) || id.contains(normalized))) {
        containsMatch = profile;
      }
    }

    return containsMatch;
  }

  Future<void> createOrUpdate(PhotographerProfileModel profile) async {
    await _collection.doc(profile.photographerId).set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> updateStatus({
    required String photographerId,
    required PhotographerStatus status,
    bool? isVerified,
  }) async {
    final patch = <String, dynamic>{'status': status.firestoreValue};
    if (isVerified != null) patch['isVerified'] = isVerified;
    await _collection.doc(photographerId).set(patch, SetOptions(merge: true));
  }

  Future<void> updateCounters({
    required String photographerId,
    int? publishedPhotoCount,
    int? activeGalleryCount,
    int? activePackCount,
    int? storageUsedBytes,
    int? salesCount,
    double? averageRating,
    double? totalRevenueGross,
    double? totalRevenueNet,
  }) async {
    final patch = <String, dynamic>{
      'publishedPhotoCount': ?publishedPhotoCount,
      'activeGalleryCount': ?activeGalleryCount,
      'activePackCount': ?activePackCount,
      'storageUsedBytes': ?storageUsedBytes,
      'salesCount': ?salesCount,
      'averageRating': ?averageRating,
      'totalRevenueGross': ?totalRevenueGross,
      'totalRevenueNet': ?totalRevenueNet,
    };
    await _collection.doc(photographerId).set(patch, SetOptions(merge: true));
  }

  Future<void> updateSubscriptionInfo({
    required String photographerId,
    String? activeSubscriptionId,
    String? activePlanId,
  }) async {
    await _collection.doc(photographerId).set({
      'activeSubscriptionId': activeSubscriptionId,
      'activePlanId': activePlanId,
    }, SetOptions(merge: true));
  }
}