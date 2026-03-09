import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../models/media_pack_model.dart';

class MediaPackRepository {
  MediaPackRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.mediaPacks);

  Future<String> createPack(MediaPackModel pack) async {
    final docId = pack.packId.isNotEmpty ? pack.packId : _collection.doc().id;
    await _collection.doc(docId).set(pack.copyWith(packId: docId).toMap());
    return docId;
  }

  Future<void> updatePack({
    required String packId,
    required Map<String, dynamic> patch,
  }) async {
    await _collection.doc(packId).set(patch, SetOptions(merge: true));
  }

  Future<List<MediaPackModel>> getByGallery(String galleryId) async {
    final snapshot = await _collection
        .where('galleryId', isEqualTo: galleryId)
        .orderBy('sortOrder')
        .get();
    return snapshot.docs.map(MediaPackModel.fromDocument).toList(growable: false);
  }

  Future<List<MediaPackModel>> getActiveByGallery(String galleryId) async {
    final snapshot = await _collection
        .where('galleryId', isEqualTo: galleryId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .get();
    return snapshot.docs.map(MediaPackModel.fromDocument).toList(growable: false);
  }

  Future<MediaPackModel?> getById(String packId) async {
    final doc = await _collection.doc(packId).get();
    if (!doc.exists) return null;
    return MediaPackModel.fromDocument(doc);
  }

  Future<void> setActive({required String packId, required bool isActive}) async {
    await _collection.doc(packId).set({'isActive': isActive}, SetOptions(merge: true));
  }
}