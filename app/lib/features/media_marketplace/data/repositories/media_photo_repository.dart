import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/enums/photo_lifecycle_status.dart';
import '../models/media_photo_model.dart';

class MediaPhotoRepository {
  MediaPhotoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.mediaPhotos);

  Future<String> createPhotoDraft(MediaPhotoModel photo) async {
    final docId = photo.photoId.isNotEmpty ? photo.photoId : _collection.doc().id;
    await _collection.doc(docId).set(photo.copyWith(photoId: docId).toMap());
    return docId;
  }

  Future<void> updateProcessedPhoto({
    required String photoId,
    required Map<String, dynamic> patch,
  }) async {
    await _collection.doc(photoId).set(patch, SetOptions(merge: true));
  }

  Future<List<MediaPhotoModel>> getByGallery(String galleryId) async {
    final snapshot = await _collection
        .where('galleryId', isEqualTo: galleryId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(MediaPhotoModel.fromDocument).toList(growable: false);
  }

  Future<List<MediaPhotoModel>> getPublishedByGallery(String galleryId) async {
    final snapshot = await _collection
        .where('galleryId', isEqualTo: galleryId)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(MediaPhotoModel.fromDocument).toList(growable: false);
  }

  Future<void> publishPhoto(String photoId) async {
    await _collection.doc(photoId).set({
      'isPublished': true,
      'lifecycleStatus': PhotoLifecycleStatus.published.firestoreValue,
    }, SetOptions(merge: true));
  }

  Future<void> archivePhoto(String photoId) async {
    await _collection.doc(photoId).set({
      'isPublished': false,
      'lifecycleStatus': PhotoLifecycleStatus.archived.firestoreValue,
    }, SetOptions(merge: true));
  }

  Future<void> updateSaleInfo({
    required String photoId,
    required bool isForSale,
    double? unitPrice,
    String? currency,
  }) async {
    await _collection.doc(photoId).set({
      'isForSale': isForSale,
      if (unitPrice != null) 'unitPrice': unitPrice,
      if (currency != null) 'currency': currency,
    }, SetOptions(merge: true));
  }

  Future<List<MediaPhotoModel>> getByIds(List<String> photoIds) async {
    if (photoIds.isEmpty) return const <MediaPhotoModel>[];
    final futures = <Future<DocumentSnapshot<Map<String, dynamic>>>>[];
    for (final photoId in photoIds) {
      futures.add(_collection.doc(photoId).get());
    }
    final docs = await Future.wait(futures);
    return docs
        .where((doc) => doc.exists)
        .map(MediaPhotoModel.fromDocument)
        .toList(growable: false);
  }
}