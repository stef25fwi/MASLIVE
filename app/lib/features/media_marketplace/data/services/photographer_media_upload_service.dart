import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as image_lib;
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
    return data['galleryId']?.toString() ?? '';
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
      final bytes = await file.readAsBytes();
      final decoded = image_lib.decodeImage(bytes);
      if (decoded == null) {
        throw StateError('Image illisible : ${file.name}');
      }

      final preview = decoded.width > 1600
          ? image_lib.copyResize(decoded, width: 1600)
          : decoded;
      final thumb = decoded.width > 480
          ? image_lib.copyResize(decoded, width: 480)
          : decoded;
      final previewBytes =
          Uint8List.fromList(image_lib.encodeJpg(preview, quality: 82));
      final thumbBytes =
          Uint8List.fromList(image_lib.encodeJpg(thumb, quality: 74));

      onProgress(PhotographerUploadProgress(
        completed: index,
        total: files.length,
        fileName: file.name,
        stage: 'Envoi de l’original',
      ));

      final contentType = file.mimeType ?? _guessMimeType(file.name);
      final customMetadata = <String, String>{
        'photographerId': photographerId,
        'galleryId': galleryId,
        'photoId': reservation['photoId'].toString(),
        'reservationId': reservation['reservationId'].toString(),
      };
      final originalMetadata = SettableMetadata(
        contentType: contentType,
        cacheControl: 'private,no-store',
        customMetadata: customMetadata,
      );

      final originalRef = _storage.ref(reservation['originalPath'].toString());
      await originalRef.putData(bytes, originalMetadata);

      onProgress(PhotographerUploadProgress(
        completed: index,
        total: files.length,
        fileName: file.name,
        stage: 'Création des miniatures',
      ));

      final derivativeMetadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=31536000,immutable',
        customMetadata: customMetadata,
      );
      final previewRef = _storage.ref(reservation['previewPath'].toString());
      final thumbnailRef =
          _storage.ref(reservation['thumbnailPath'].toString());
      final watermarkedRef =
          _storage.ref(reservation['watermarkedPath'].toString());

      await Future.wait<TaskSnapshot>(<Future<TaskSnapshot>>[
        previewRef.putData(previewBytes, derivativeMetadata),
        thumbnailRef.putData(thumbBytes, derivativeMetadata),
        // La boutique superpose également un filigrane visuel. Cette copie basse
        // définition garantit qu’aucun original n’est exposé publiquement.
        watermarkedRef.putData(previewBytes, derivativeMetadata),
      ]);

      final urls = await Future.wait<String>(<Future<String>>[
        previewRef.getDownloadURL(),
        thumbnailRef.getDownloadURL(),
        watermarkedRef.getDownloadURL(),
      ]);

      await _functions
          .httpsCallable('finalizePhotographerMediaUpload')
          .call(<String, dynamic>{
        'reservationId': reservation['reservationId'],
        'photoId': reservation['photoId'],
        'width': decoded.width,
        'height': decoded.height,
        'sizeBytes': bytes.length,
        'mimeType': contentType,
        'downloadFileName': file.name,
        'originalPath': reservation['originalPath'],
        'previewPath': urls[0],
        'thumbnailPath': urls[1],
        'watermarkedPath': urls[2],
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

  Future<void> createRecommendedPacks({
    required String photographerId,
    required String galleryId,
  }) async {
    await _functions
        .httpsCallable('ensurePhotographerGalleryDefaultPacks')
        .call(<String, dynamic>{
      'photographerId': photographerId,
      'galleryId': galleryId,
    });
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
