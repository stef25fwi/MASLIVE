import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PhotographerUploadProgress {
  const PhotographerUploadProgress({
    required this.completed,
    required this.total,
    required this.fileName,
    required this.stage,
  });

  final int completed;
  final int total;
  final String fileName;
  final String stage;

  double get fraction => total <= 0 ? 0 : completed / total;
}

class PhotographerMediaQuota {
  const PhotographerMediaQuota({
    required this.planCode,
    required this.planName,
    required this.maxPublishedPhotos,
    required this.maxStorageBytes,
    required this.maxActiveGalleries,
    required this.maxBatchUpload,
    required this.maxFileBytes,
    required this.maxMegapixels,
    required this.retentionDays,
    required this.commissionRate,
    required this.publishedPhotoCount,
    required this.storageUsedBytes,
    required this.activeGalleryCount,
    required this.photoCapacityRemaining,
    required this.storageCapacityRemaining,
    required this.galleryCapacityRemaining,
  });

  final String planCode;
  final String planName;
  final int maxPublishedPhotos;
  final int maxStorageBytes;
  final int maxActiveGalleries;
  final int maxBatchUpload;
  final int maxFileBytes;
  final int maxMegapixels;
  final int retentionDays;
  final double commissionRate;
  final int publishedPhotoCount;
  final int storageUsedBytes;
  final int activeGalleryCount;
  final int photoCapacityRemaining;
  final int storageCapacityRemaining;
  final int galleryCapacityRemaining;

  double get photoUsageFraction => maxPublishedPhotos <= 0
      ? 0
      : (publishedPhotoCount / maxPublishedPhotos).clamp(0, 1).toDouble();

  double get storageUsageFraction => maxStorageBytes <= 0
      ? 0
      : (storageUsedBytes / maxStorageBytes).clamp(0, 1).toDouble();

  int get commissionPercent => (commissionRate * 100).round();

  factory PhotographerMediaQuota.fromMap(Map<String, dynamic> map) {
    final plan = Map<String, dynamic>.from(
      map['plan'] is Map ? map['plan'] as Map : const <String, dynamic>{},
    );
    int readInt(Map<String, dynamic> source, String key) {
      final value = source[key];
      return value is num ? value.toInt() : 0;
    }

    double readDouble(Map<String, dynamic> source, String key) {
      final value = source[key];
      return value is num ? value.toDouble() : 0;
    }

    return PhotographerMediaQuota(
      planCode: plan['code']?.toString() ?? 'discovery',
      planName: plan['name']?.toString() ?? 'Découverte',
      maxPublishedPhotos: readInt(plan, 'maxPublishedPhotos'),
      maxStorageBytes: readInt(plan, 'maxStorageBytes'),
      maxActiveGalleries: readInt(plan, 'maxActiveGalleries'),
      maxBatchUpload: readInt(plan, 'maxBatchUpload'),
      maxFileBytes: readInt(plan, 'maxFileBytes'),
      maxMegapixels: readInt(plan, 'maxMegapixels'),
      retentionDays: readInt(plan, 'retentionDays'),
      commissionRate: readDouble(plan, 'commissionRate'),
      publishedPhotoCount: readInt(map, 'publishedPhotoCount'),
      storageUsedBytes: readInt(map, 'storageUsedBytes'),
      activeGalleryCount: readInt(map, 'activeGalleryCount'),
      photoCapacityRemaining: readInt(map, 'photoCapacityRemaining'),
      storageCapacityRemaining: readInt(map, 'storageCapacityRemaining'),
      galleryCapacityRemaining: readInt(map, 'galleryCapacityRemaining'),
    );
  }
}

class PhotographerMediaUploadService {
  PhotographerMediaUploadService({
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-east1'),
        _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  Future<PhotographerMediaQuota> getQuota(String photographerId) async {
    final response = await _functions
        .httpsCallable('getPhotographerMediaQuota')
        .call(<String, dynamic>{'photographerId': photographerId});
    return PhotographerMediaQuota.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<XFile>> selectPhotos({required int maxCount}) async {
    if (maxCount <= 0) return const <XFile>[];
    final selected = await _picker.pickMultiImage(imageQuality: 100);
    if (selected.length <= maxCount) return selected;
    return selected.take(maxCount).toList(growable: false);
  }

  Future<String> createGallery({
    required String photographerId,
    required String title,
    required String eventId,
    required String circuitId,
    required String countryId,
    String? description,
    String? eventName,
    String? circuitName,
    String? countryName,
  }) async {
    final response = await _functions
        .httpsCallable('createPhotographerMediaGallery')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'title': title,
      'description': description,
      'eventId': eventId,
      'eventName': eventName,
      'circuitId': circuitId,
      'circuitName': circuitName,
      'countryId': countryId,
      'countryName': countryName,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final galleryId = data['galleryId']?.toString() ?? '';
    if (galleryId.isEmpty) {
      throw StateError('La galerie n’a pas été créée.');
    }
    return galleryId;
  }

  Future<void> uploadPhotos({
    required String photographerId,
    required String galleryId,
    required List<XFile> files,
    required double unitPrice,
    required void Function(PhotographerUploadProgress progress) onProgress,
  }) async {
    if (files.isEmpty) return;

    final manifests = <Map<String, dynamic>>[];
    for (final file in files) {
      manifests.add(<String, dynamic>{
        'fileName': file.name,
        'mimeType': file.mimeType ?? _guessMimeType(file.name),
        'sizeBytes': await file.length(),
      });
    }

    final reservationResponse = await _functions
        .httpsCallable('reservePhotographerMediaUploads')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'galleryId': galleryId,
      'files': manifests,
    });
    final reservationData =
        Map<String, dynamic>.from(reservationResponse.data as Map);
    final reservations =
        (reservationData['uploads'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(growable: false);

    if (reservations.length != files.length) {
      throw StateError('Le serveur n’a pas réservé tous les fichiers.');
    }

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final reservation = reservations[index];
      final contentType = file.mimeType ?? _guessMimeType(file.name);
      final customMetadata = <String, String>{
        'photographerId': photographerId,
        'galleryId': galleryId,
        'photoId': reservation['photoId'].toString(),
        'reservationId': reservation['reservationId'].toString(),
      };

      onProgress(PhotographerUploadProgress(
        completed: index,
        total: files.length,
        fileName: file.name,
        stage: 'Envoi de l’original',
      ));

      final originalRef = _storage.ref(reservation['originalPath'].toString());
      await originalRef.putData(
        await file.readAsBytes(),
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'private,no-store',
          customMetadata: customMetadata,
        ),
      );

      onProgress(PhotographerUploadProgress(
        completed: index,
        total: files.length,
        fileName: file.name,
        stage: 'Optimisation et filigrane',
      ));

      await _functions
          .httpsCallable('finalizePhotographerMediaUpload')
          .call(<String, dynamic>{
        'reservationId': reservation['reservationId'],
        'photoId': reservation['photoId'],
        'unitPrice': unitPrice,
      });

      onProgress(PhotographerUploadProgress(
        completed: index + 1,
        total: files.length,
        fileName: file.name,
        stage: 'Photo prête',
      ));
    }
  }

  Future<void> publishGallery({
    required String photographerId,
    required String galleryId,
  }) async {
    await _functions
        .httpsCallable('publishPhotographerMediaGallery')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'galleryId': galleryId,
    });
  }

  Future<void> archiveGallery({
    required String photographerId,
    required String galleryId,
  }) async {
    await _functions
        .httpsCallable('archivePhotographerMediaGallery')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'galleryId': galleryId,
    });
  }

  Future<int> createRecommendedPacks({
    required String photographerId,
    required String galleryId,
  }) async {
    final response = await _functions
        .httpsCallable('ensurePhotographerGalleryDefaultPacks')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'galleryId': galleryId,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final created = data['created'];
    return created is num ? created.toInt() : 0;
  }

  Future<void> deletePhoto({
    required String photographerId,
    required String photoId,
  }) async {
    await _functions
        .httpsCallable('deletePhotographerMediaPhoto')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'photoId': photoId,
    });
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }
}
