import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/enums/photo_lifecycle_status.dart';
import '../../core/pagination/media_gallery_pagination.dart';
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
    final page = await getPublishedPageByGallery(galleryId, pageSize: maxMediaGalleryPageSize);
    return page.items;
  }

  Future<MediaGalleryPage<MediaPhotoModel>> getPublishedPageByGallery(
    String galleryId, {
    MediaGalleryCursor? cursor,
    int pageSize = defaultMediaGalleryPageSize,
  }) async {
    final normalizedGalleryId = galleryId.trim();
    if (normalizedGalleryId.isEmpty) {
      return const MediaGalleryPage<MediaPhotoModel>(
        items: <MediaPhotoModel>[],
        hasMore: false,
      );
    }

    final normalizedPageSize = normalizeMediaGalleryPageSize(pageSize);
    Query<Map<String, dynamic>> query = _collection
        .where('galleryId', isEqualTo: normalizedGalleryId)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);

    if (cursor != null) {
      query = query.startAfter(<Object>[
        Timestamp.fromMillisecondsSinceEpoch(cursor.createdAtMillis),
        cursor.photoId,
      ]);
    }

    final snapshot = await query.limit(normalizedPageSize + 1).get();
    final hasMore = snapshot.docs.length > normalizedPageSize;
    final pageDocs = hasMore
        ? snapshot.docs.take(normalizedPageSize).toList(growable: false)
        : snapshot.docs;
    final items = pageDocs
        .map(MediaPhotoModel.fromDocument)
        .toList(growable: false);

    MediaGalleryCursor? nextCursor;
    if (hasMore && pageDocs.isNotEmpty) {
      final last = pageDocs.last;
      final rawCreatedAt = last.data()['createdAt'];
      final createdAt = rawCreatedAt is Timestamp
          ? rawCreatedAt
          : Timestamp.fromDate(items.last.createdAt);
      nextCursor = MediaGalleryCursor(
        createdAtMillis: createdAt.millisecondsSinceEpoch,
        photoId: last.id,
      );
    }

    return MediaGalleryPage<MediaPhotoModel>(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
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
      'unitPrice': ?unitPrice,
      'currency': ?currency,
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
