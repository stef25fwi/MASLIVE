import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/enums/gallery_status.dart';
import '../models/media_gallery_model.dart';

class MediaGalleryRepository {
  MediaGalleryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.mediaGalleries);

  Future<String> createGallery(MediaGalleryModel gallery) async {
    final docId = gallery.galleryId.isNotEmpty ? gallery.galleryId : _collection.doc().id;
    await _collection.doc(docId).set(gallery.copyWith(galleryId: docId).toMap());
    return docId;
  }

  Future<void> updateGallery({
    required String galleryId,
    required Map<String, dynamic> patch,
  }) async {
    await _collection.doc(galleryId).set(patch, SetOptions(merge: true));
  }

  Future<MediaGalleryModel?> getById(String galleryId) async {
    final doc = await _collection.doc(galleryId).get();
    if (!doc.exists) return null;
    return MediaGalleryModel.fromDocument(doc);
  }

  Future<List<MediaGalleryModel>> getByEvent(String eventId) async {
    final snapshot = await _collection
        .where('eventId', isEqualTo: eventId)
        .orderBy('publishedAt', descending: true)
        .get();
    return snapshot.docs.map(MediaGalleryModel.fromDocument).toList(growable: false);
  }

  Future<List<MediaGalleryModel>> getByPhotographer(String photographerId) async {
    final snapshot = await _collection
        .where('photographerId', isEqualTo: photographerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(MediaGalleryModel.fromDocument).toList(growable: false);
  }

  Future<void> publishGallery(String galleryId, {DateTime? publishedAt}) async {
    await _collection.doc(galleryId).set({
      'status': GalleryStatus.published.firestoreValue,
      'publishedAt': Timestamp.fromDate(publishedAt ?? DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<void> archiveGallery(String galleryId) async {
    await _collection.doc(galleryId).set({
      'status': GalleryStatus.archived.firestoreValue,
    }, SetOptions(merge: true));
  }

  Future<void> updateCounters({
    required String galleryId,
    int? photoCount,
    int? publishedPhotoCount,
    int? packCount,
    String? coverPhotoId,
    String? coverUrl,
  }) async {
    await _collection.doc(galleryId).set({
      if (photoCount != null) 'photoCount': photoCount,
      if (publishedPhotoCount != null) 'publishedPhotoCount': publishedPhotoCount,
      if (packCount != null) 'packCount': packCount,
      if (coverPhotoId != null) 'coverPhotoId': coverPhotoId,
      if (coverUrl != null) 'coverUrl': coverUrl,
    }, SetOptions(merge: true));
  }
}