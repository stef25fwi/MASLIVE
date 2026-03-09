import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/enums/media_asset_type.dart';
import '../models/media_entitlement_model.dart';

class MediaEntitlementRepository {
  MediaEntitlementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.mediaEntitlements);

  Future<String> createEntitlement(MediaEntitlementModel entitlement) async {
    final docId = entitlement.entitlementId.isNotEmpty
        ? entitlement.entitlementId
        : _collection.doc().id;
    await _collection.doc(docId).set(
      entitlement.copyWith(entitlementId: docId).toMap(),
    );
    return docId;
  }

  Future<List<MediaEntitlementModel>> getByBuyer(String buyerUid) async {
    final snapshot = await _collection
        .where('buyerUid', isEqualTo: buyerUid)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(MediaEntitlementModel.fromDocument).toList(growable: false);
  }

  Future<List<MediaEntitlementModel>> getByOrder(String orderId) async {
    final snapshot = await _collection.where('orderId', isEqualTo: orderId).get();
    return snapshot.docs.map(MediaEntitlementModel.fromDocument).toList(growable: false);
  }

  Future<MediaEntitlementModel?> getByAssetAndBuyer({
    required String buyerUid,
    required String assetId,
    MediaAssetType? assetType,
  }) async {
    Query<Map<String, dynamic>> query = _collection
        .where('buyerUid', isEqualTo: buyerUid)
        .where('assetId', isEqualTo: assetId)
        .limit(1);
    if (assetType != null) {
      query = query.where('assetType', isEqualTo: assetType.firestoreValue);
    }
    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return null;
    return MediaEntitlementModel.fromDocument(snapshot.docs.first);
  }

  Future<void> incrementDownloadCount(String entitlementId) async {
    await _collection.doc(entitlementId).set({
      'downloadCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}