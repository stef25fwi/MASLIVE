import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/media_gallery_model.dart';
import '../models/media_order_model.dart';
import '../models/media_photo_model.dart';
import '../models/photographer_profile_model.dart';

class PhotographerPhotoPage {
  const PhotographerPhotoPage({
    required this.photos,
    required this.documents,
    required this.hasMore,
  });

  final List<MediaPhotoModel> photos;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;
  final bool hasMore;

  DocumentSnapshot<Map<String, dynamic>>? get cursor =>
      documents.isEmpty ? null : documents.last;
}

class PhotographerCompleteFlowRepository {
  PhotographerCompleteFlowRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> loadAdvancedDashboard({
    required String photographerId,
    String? eventId,
  }) async {
    final response = await _functions
        .httpsCallable('getPhotographerAdvancedDashboard')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      if (eventId?.trim().isNotEmpty == true) 'eventId': eventId!.trim(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> loadWorkspaceConfig(String photographerId) async {
    final response = await _functions
        .httpsCallable('getPhotographerWorkspaceConfig')
        .call(<String, dynamic>{'photographerId': photographerId});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> saveWorkspaceConfig({
    required String photographerId,
    required Map<String, dynamic> config,
  }) async {
    final response = await _functions
        .httpsCallable('savePhotographerWorkspaceConfig')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'config': config,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<MediaGalleryModel>> loadGalleries(String photographerId) async {
    final snapshot = await _firestore
        .collection('media_galleries')
        .where('photographerId', isEqualTo: photographerId)
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs.map(MediaGalleryModel.fromDocument).toList(growable: false);
  }

  Future<void> updateGallery({
    required String galleryId,
    required Map<String, dynamic> patch,
  }) async {
    await _firestore.collection('media_galleries').doc(galleryId).set(
      <String, dynamic>{
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> duplicateGallery({
    required String photographerId,
    required String galleryId,
  }) async {
    final response = await _functions
        .httpsCallable('duplicatePhotographerGallery')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'galleryId': galleryId,
    });
    return Map<String, dynamic>.from(response.data as Map)['galleryId']?.toString() ?? '';
  }

  Future<void> deleteGallery({
    required String photographerId,
    required String galleryId,
  }) async {
    await _functions.httpsCallable('deletePhotographerGallery').call(<String, dynamic>{
      'photographerId': photographerId,
      'galleryId': galleryId,
    });
  }

  Future<String> generatePrivateLink({
    required String photographerId,
    required String galleryId,
  }) async {
    final response = await _functions
        .httpsCallable('generateGalleryPrivateLink')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'galleryId': galleryId,
    });
    return Map<String, dynamic>.from(response.data as Map)['url']?.toString() ?? '';
  }

  Future<PhotographerPhotoPage> loadPhotoPage({
    required String photographerId,
    String? galleryId,
    String? status,
    String? queryText,
    String? bibNumber,
    DateTime? from,
    DateTime? to,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    int pageSize = 60,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('media_photos')
        .where('photographerId', isEqualTo: photographerId);
    if (galleryId?.isNotEmpty == true) {
      query = query.where('galleryId', isEqualTo: galleryId);
    }
    if (status?.isNotEmpty == true && status != 'all') {
      if (status == 'pending') {
        query = query.where('moderationStatus', isEqualTo: 'pending');
      } else {
        query = query.where('lifecycleStatus', isEqualTo: status);
      }
    }
    if (from != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }
    query = query.orderBy('createdAt', descending: true).limit(pageSize + 1);
    if (cursor != null) query = query.startAfterDocument(cursor);
    final snapshot = await query.get();
    final raw = snapshot.docs.take(pageSize).toList(growable: false);
    final normalizedQuery = queryText?.trim().toLowerCase() ?? '';
    final normalizedBib = bibNumber?.trim().toLowerCase() ?? '';
    final filtered = raw.where((doc) {
      final data = doc.data();
      final searchable = <String>[
        doc.id,
        data['eventName']?.toString() ?? '',
        data['downloadFileName']?.toString() ?? '',
        ...(data['tags'] as Iterable? ?? const <dynamic>[]).map((value) => value.toString()),
        ...(data['colorTags'] as Iterable? ?? const <dynamic>[]).map((value) => value.toString()),
        ...(data['bibNumbers'] as Iterable? ?? const <dynamic>[]).map((value) => value.toString()),
      ].join(' ').toLowerCase();
      if (normalizedQuery.isNotEmpty && !searchable.contains(normalizedQuery)) return false;
      if (normalizedBib.isNotEmpty && !searchable.contains(normalizedBib)) return false;
      return true;
    }).toList(growable: false);
    return PhotographerPhotoPage(
      photos: filtered.map(MediaPhotoModel.fromDocument).toList(growable: false),
      documents: filtered,
      hasMore: snapshot.docs.length > pageSize,
    );
  }

  Future<void> updatePhotoMetadata({
    required String photoId,
    required String actorUid,
    List<String>? tags,
    List<String>? faceTags,
    List<String>? bibNumbers,
    List<String>? colorTags,
    double? unitPrice,
    String? galleryId,
  }) async {
    await _firestore.collection('media_photos').doc(photoId).set(
      <String, dynamic>{
        if (tags != null) 'tags': _cleanList(tags),
        if (faceTags != null) 'faceTags': _cleanList(faceTags),
        if (bibNumbers != null) 'bibNumbers': _cleanList(bibNumbers),
        if (colorTags != null) 'colorTags': _cleanList(colorTags),
        if (unitPrice != null) ...<String, dynamic>{
          'unitPrice': unitPrice,
          'isForSale': true,
        },
        if (galleryId != null) 'galleryId': galleryId,
        'history': FieldValue.arrayUnion(<Map<String, dynamic>>[
          <String, dynamic>{
            'action': 'metadata_updated',
            'actorUid': actorUid,
            'at': Timestamp.now(),
            if (galleryId != null) 'galleryId': galleryId,
            if (unitPrice != null) 'unitPrice': unitPrice,
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> bulkUpdatePhotos({
    required Iterable<String> photoIds,
    required String actorUid,
    double? unitPrice,
    String? galleryId,
    bool? published,
    List<String>? addTags,
  }) async {
    final ids = photoIds.toList(growable: false);
    for (var offset = 0; offset < ids.length; offset += 400) {
      final batch = _firestore.batch();
      for (final id in ids.skip(offset).take(400)) {
        final ref = _firestore.collection('media_photos').doc(id);
        batch.set(
          ref,
          <String, dynamic>{
            if (unitPrice != null) ...<String, dynamic>{
              'unitPrice': unitPrice,
              'isForSale': true,
            },
            if (galleryId != null) 'galleryId': galleryId,
            if (published != null) ...<String, dynamic>{
              'isPublished': published,
              'lifecycleStatus': published ? 'published' : 'archived',
            },
            if (addTags != null && addTags.isNotEmpty)
              'tags': FieldValue.arrayUnion(_cleanList(addTags)),
            'history': FieldValue.arrayUnion(<Map<String, dynamic>>[
              <String, dynamic>{
                'action': 'bulk_update',
                'actorUid': actorUid,
                'at': Timestamp.now(),
                if (galleryId != null) 'galleryId': galleryId,
                if (unitPrice != null) 'unitPrice': unitPrice,
                if (published != null) 'published': published,
              },
            ]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<List<MediaOrderModel>> loadOrders(String photographerId) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('photographerIds', arrayContains: photographerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(MediaOrderModel.fromDocument).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadPayouts(String photographerId) async {
    final snapshot = await _firestore
        .collection('payout_ledger')
        .where('photographerId', isEqualTo: photographerId)
        .get();
    final rows = snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList(growable: false);
    rows.sort((a, b) => _dateOf(b['createdAt']).compareTo(_dateOf(a['createdAt'])));
    return rows;
  }

  Future<Map<String, dynamic>> generateExport({
    required String photographerId,
    required String kind,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _functions
        .httpsCallable('generatePhotographerExport')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'kind': kind,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createApiKey({
    required String photographerId,
    required String label,
  }) async {
    final response = await _functions
        .httpsCallable('createPhotographerApiKey')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'label': label,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> revokeApiKey({
    required String photographerId,
    required String keyId,
  }) async {
    await _functions.httpsCallable('revokePhotographerApiKey').call(<String, dynamic>{
      'photographerId': photographerId,
      'keyId': keyId,
    });
  }

  Future<List<Map<String, dynamic>>> loadAudit(String photographerId) async {
    final snapshot = await _firestore
        .collection('photographer_audit_log')
        .where('photographerId', isEqualTo: photographerId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  static List<String> _cleanList(Iterable<String> values) => values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .take(100)
      .toList(growable: false);

  static DateTime _dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}
