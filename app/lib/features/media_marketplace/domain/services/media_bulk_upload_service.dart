import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../../core/constants/media_marketplace_storage_paths.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/photographer_profile_model.dart';

class MediaUploadProgress {
  const MediaUploadProgress({
    required this.completed,
    required this.total,
    required this.currentFile,
    required this.bytesTransferred,
    required this.totalBytes,
  });

  final int completed;
  final int total;
  final String currentFile;
  final int bytesTransferred;
  final int totalBytes;

  double get fraction {
    if (totalBytes <= 0) return total <= 0 ? 0 : completed / total;
    return (bytesTransferred / totalBytes).clamp(0, 1).toDouble();
  }
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.uploadedPhotoIds,
    required this.rejectedFiles,
    required this.uploadedBytes,
  });

  final List<String> uploadedPhotoIds;
  final Map<String, String> rejectedFiles;
  final int uploadedBytes;
}

class MediaBulkUploadService {
  MediaBulkUploadService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _imagePicker = imagePicker ?? ImagePicker();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;

  Future<List<XFile>> pickPhotos() {
    return _imagePicker.pickMultiImage(
      imageQuality: 100,
      requestFullMetadata: true,
    );
  }

  Future<MediaUploadResult> uploadPhotos({
    required PhotographerProfileModel profile,
    required MediaGalleryModel gallery,
    required List<XFile> files,
    required void Function(MediaUploadProgress progress) onProgress,
  }) async {
    if (files.isEmpty) {
      return const MediaUploadResult(
        uploadedPhotoIds: <String>[],
        rejectedFiles: <String, String>{},
        uploadedBytes: 0,
      );
    }

    final plan = MediaMarketplacePricing.planFor(profile.activePlanId);
    final extensionData = profile.metadata?['storageExtensions'];
    final extensions = extensionData is Map
        ? Map<String, dynamic>.from(extensionData)
        : const <String, dynamic>{};
    final maxPhotos = plan.maxPublishedPhotos +
        ((extensions['extraPhotos'] as num?)?.toInt() ?? 0);
    final maxStorage = plan.maxStorageBytes +
        ((extensions['extraStorageBytes'] as num?)?.toInt() ?? 0);
    final remainingPhotos = maxPhotos - profile.publishedPhotoCount;
    if (remainingPhotos <= 0) {
      throw StateError(
        'Quota photo atteint. Archive des photos ou ajoute une extension.',
      );
    }
    if (files.length > remainingPhotos) {
      throw StateError(
        'Tu peux encore importer $remainingPhotos photo(s) avec la formule ${plan.name}.',
      );
    }

    final lengths = <XFile, int>{};
    var requestedBytes = 0;
    for (final file in files) {
      final length = await file.length();
      lengths[file] = length;
      requestedBytes += length;
    }
    final remainingStorage = maxStorage - profile.storageUsedBytes;
    if (requestedBytes > remainingStorage) {
      throw StateError(
        'Stockage insuffisant : ${(remainingStorage / (1024 * 1024)).floor()} Mo restant(s).',
      );
    }

    final uploaded = <String>[];
    final rejected = <String, String>{};
    var uploadedBytes = 0;

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final fileLength = lengths[file] ?? await file.length();
      try {
        if (fileLength > plan.maxFileBytes) {
          throw StateError(
            'Fichier supérieur à ${(plan.maxFileBytes / (1024 * 1024)).round()} Mo.',
          );
        }

        final bytes = await file.readAsBytes();
        final decoded = image_lib.decodeImage(bytes);
        if (decoded == null) {
          throw StateError('Format image illisible. Utilise JPEG, PNG ou WebP.');
        }
        final megapixels = (decoded.width * decoded.height) / 1000000;
        if (megapixels > plan.maxMegapixels) {
          throw StateError(
            'Définition ${megapixels.toStringAsFixed(1)} MP supérieure au quota ${plan.maxMegapixels} MP.',
          );
        }

        final photoRef = _firestore
            .collection(MediaMarketplaceCollections.mediaPhotos)
            .doc();
        final photoId = photoRef.id;
        final extension = _extensionFor(file.name);
        final originalPath = MediaMarketplaceStoragePaths.originalPath(
          photographerId: profile.photographerId,
          eventId: gallery.eventId,
          galleryId: gallery.galleryId,
          photoId: photoId,
          extension: extension,
        );
        final previewPath = MediaMarketplaceStoragePaths.previewPath(
          photographerId: profile.photographerId,
          eventId: gallery.eventId,
          galleryId: gallery.galleryId,
          photoId: photoId,
          extension: 'webp',
        );
        final thumbnailPath = MediaMarketplaceStoragePaths.thumbnailPath(
          photographerId: profile.photographerId,
          eventId: gallery.eventId,
          galleryId: gallery.galleryId,
          photoId: photoId,
          extension: 'webp',
        );
        final watermarkedPath = MediaMarketplaceStoragePaths.watermarkedPath(
          photographerId: profile.photographerId,
          eventId: gallery.eventId,
          galleryId: gallery.galleryId,
          photoId: photoId,
          extension: 'webp',
        );

        final uploadTask = _storage.ref(originalPath).putData(
          Uint8List.fromList(bytes),
          SettableMetadata(
            contentType: _contentTypeFor(extension),
            cacheControl: 'private,max-age=0,no-store',
            customMetadata: <String, String>{
              'ownerUid': profile.ownerUid,
              'photographerId': profile.photographerId,
              'galleryId': gallery.galleryId,
              'eventId': gallery.eventId,
              'photoId': photoId,
              'planCode': plan.code,
              'retentionDays': '${plan.retentionDays}',
            },
          ),
        );

        uploadTask.snapshotEvents.listen((snapshot) {
          onProgress(
            MediaUploadProgress(
              completed: index,
              total: files.length,
              currentFile: file.name,
              bytesTransferred: uploadedBytes + snapshot.bytesTransferred,
              totalBytes: requestedBytes,
            ),
          );
        });
        await uploadTask;

        final now = DateTime.now();
        final purgeAt = now.add(Duration(days: plan.retentionDays + 30));
        await photoRef.set(<String, dynamic>{
          'photoId': photoId,
          'photographerId': profile.photographerId,
          'ownerUid': profile.ownerUid,
          'galleryId': gallery.galleryId,
          'eventId': gallery.eventId,
          'eventName': gallery.title,
          'countryId': gallery.linkedCountry ?? '',
          'circuitId': gallery.linkedCircuitId ?? '',
          'originalPath': originalPath,
          'previewPath': previewPath,
          'thumbnailPath': thumbnailPath,
          'watermarkedPath': watermarkedPath,
          'downloadFileName': _safeDownloadName(file.name, photoId),
          'width': decoded.width,
          'height': decoded.height,
          'sizeBytes': fileLength,
          'mimeType': _contentTypeFor(extension),
          'tags': <String>[],
          'faceTags': <String>[],
          'moderationStatus': 'pending',
          'lifecycleStatus': 'draft',
          'visibility': 'private',
          'processingStatus': 'queued',
          'isPublished': false,
          'isForSale': false,
          'unitPrice': 6.90,
          'currency': 'EUR',
          'retentionDays': plan.retentionDays,
          'purgeAt': Timestamp.fromDate(purgeAt),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        uploaded.add(photoId);
        uploadedBytes += fileLength;
        onProgress(
          MediaUploadProgress(
            completed: index + 1,
            total: files.length,
            currentFile: file.name,
            bytesTransferred: uploadedBytes,
            totalBytes: requestedBytes,
          ),
        );
      } catch (error) {
        rejected[file.name] = error.toString().replaceFirst('Bad state: ', '');
      }
    }

    return MediaUploadResult(
      uploadedPhotoIds: List<String>.unmodifiable(uploaded),
      rejectedFiles: Map<String, String>.unmodifiable(rejected),
      uploadedBytes: uploadedBytes,
    );
  }

  String _extensionFor(String name) {
    final parts = name.toLowerCase().split('.');
    final extension = parts.length > 1 ? parts.last : 'jpg';
    switch (extension) {
      case 'jpeg':
        return 'jpg';
      case 'jpg':
      case 'png':
      case 'webp':
        return extension;
      default:
        return 'jpg';
    }
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _safeDownloadName(String original, String photoId) {
    final cleaned = original
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return cleaned.isEmpty ? 'maslive_$photoId.jpg' : cleaned;
  }
}
