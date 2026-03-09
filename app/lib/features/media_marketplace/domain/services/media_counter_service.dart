import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/enums/gallery_status.dart';
import '../../data/repositories/media_gallery_repository.dart';
import '../../data/repositories/photographer_repository.dart';

class MediaCounterService {
  MediaCounterService({
    FirebaseFirestore? firestore,
    MediaGalleryRepository? mediaGalleryRepository,
    PhotographerRepository? photographerRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _mediaGalleryRepository =
           mediaGalleryRepository ?? MediaGalleryRepository(firestore: firestore),
       _photographerRepository =
           photographerRepository ?? PhotographerRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final MediaGalleryRepository _mediaGalleryRepository;
  final PhotographerRepository _photographerRepository;

  Future<void> recalculateGalleryCounters(String galleryId) async {
    final photosSnapshot = await _firestore
        .collection(MediaMarketplaceCollections.mediaPhotos)
        .where('galleryId', isEqualTo: galleryId)
        .get();
    final packsSnapshot = await _firestore
        .collection(MediaMarketplaceCollections.mediaPacks)
        .where('galleryId', isEqualTo: galleryId)
        .get();

    final photoCount = photosSnapshot.docs.length;
    final publishedPhotoCount = photosSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['isPublished'] == true;
    }).length;
    final packCount = packsSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['isActive'] == true;
    }).length;

    String? coverPhotoId;
    String? coverUrl;
    if (photosSnapshot.docs.isNotEmpty) {
      final first = photosSnapshot.docs.first.data();
      coverPhotoId = first['photoId']?.toString() ?? photosSnapshot.docs.first.id;
      coverUrl = first['thumbnailPath']?.toString() ?? first['previewPath']?.toString();
    }

    await _mediaGalleryRepository.updateCounters(
      galleryId: galleryId,
      photoCount: photoCount,
      publishedPhotoCount: publishedPhotoCount,
      packCount: packCount,
      coverPhotoId: coverPhotoId,
      coverUrl: coverUrl,
    );
  }

  Future<void> recalculatePhotographerCounters(String photographerId) async {
    final photosSnapshot = await _firestore
        .collection(MediaMarketplaceCollections.mediaPhotos)
        .where('photographerId', isEqualTo: photographerId)
        .get();
    final galleriesSnapshot = await _firestore
        .collection(MediaMarketplaceCollections.mediaGalleries)
        .where('photographerId', isEqualTo: photographerId)
        .get();
    final packsSnapshot = await _firestore
        .collection(MediaMarketplaceCollections.mediaPacks)
        .where('photographerId', isEqualTo: photographerId)
        .get();
    final payoutSnapshot = await _firestore
        .collection(MediaMarketplaceCollections.payoutLedger)
        .where('photographerId', isEqualTo: photographerId)
        .get();

    final publishedPhotoCount = photosSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['isPublished'] == true;
    }).length;

    final activeGalleryCount = galleriesSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['status'] != GalleryStatus.archived.firestoreValue;
    }).length;

    final activePackCount = packsSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['isActive'] == true;
    }).length;

    final storageUsedBytes = photosSnapshot.docs.fold<int>(0, (sum, doc) {
      final size = doc.data()['sizeBytes'];
      return sum + (size is num ? size.toInt() : 0);
    });

    final totalRevenueGross = payoutSnapshot.docs.fold<double>(0, (sum, doc) {
      final amount = doc.data()['grossAmount'];
      return sum + (amount is num ? amount.toDouble() : 0);
    });

    final totalRevenueNet = payoutSnapshot.docs.fold<double>(0, (sum, doc) {
      final amount = doc.data()['netAmount'];
      return sum + (amount is num ? amount.toDouble() : 0);
    });

    await _photographerRepository.updateCounters(
      photographerId: photographerId,
      publishedPhotoCount: publishedPhotoCount,
      activeGalleryCount: activeGalleryCount,
      activePackCount: activePackCount,
      storageUsedBytes: storageUsedBytes,
      salesCount: payoutSnapshot.docs.length,
      totalRevenueGross: totalRevenueGross,
      totalRevenueNet: totalRevenueNet,
    );
  }
}