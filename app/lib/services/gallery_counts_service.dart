import 'package:cloud_firestore/cloud_firestore.dart';

class GalleryCounts {
  const GalleryCounts({required this.photos, required this.galleries, this.isFallback = false});

  final int photos;
  final int galleries;
  final bool isFallback;
}

class GalleryCountsService {
  GalleryCountsService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<GalleryCounts> fetch({String? groupId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('media_galleries');
      final trimmed = groupId?.trim();
      if (trimmed != null && trimmed.isNotEmpty && trimmed != 'all') {
        query = query.where('groupId', isEqualTo: trimmed);
      }

      final snapshot = await query.get();
      var photos = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final photoCountField = data['photoCount'];
        if (photoCountField is int) {
          photos += photoCountField;
          continue;
        }

        final images = data['images'];
        if (images is List) {
          photos += images.length;
        }
      }

      return GalleryCounts(
        photos: photos,
        galleries: snapshot.size,
        isFallback: false,
      );
    } catch (_) {
      return const GalleryCounts(
        photos: 0,
        galleries: 0,
        isFallback: true,
      );
    }
  }
}
