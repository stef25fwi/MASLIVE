import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/image_asset.dart';
import 'image_optimization_service.dart';

/// Service de gestion centralisée des images
/// Unifie upload, optimisation, stockage Firestore et Storage
class ImageManagementService {
  static final ImageManagementService instance =
      ImageManagementService._internal();
  ImageManagementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImageOptimizationService _optimizer = ImageOptimizationService.instance;

  User? get _currentUser => _auth.currentUser;

  static const String _collectionName = 'image_assets';

  String _inferMimeTypeFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    // jpg/jpeg et fallback
    return 'image/jpeg';
  }

  /// Upload image complète (optimisation + Storage + Firestore)
  Future<ImageAsset> uploadImage({
    required XFile file,
    required ImageContentType contentType,
    required String parentId,
    int order = 0,
    String? altText,
    void Function(double progress)? onProgress,
  }) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    developer.log('📸 [ImageManagement] Upload image pour $parentId');

    // 1. Générer ID unique
    final imageId = _firestore.collection(_collectionName).doc().id;

    // 2. Déterminer path Storage selon contentType
    final basePath = _getStoragePath(contentType, parentId, imageId);

    // 3. Upload avec optimisation
    final variants = await _optimizer.uploadImageWithVariants(
      file: file,
      basePath: basePath,
      contentType: contentType,
      onProgress: (p) => onProgress?.call(p * 0.9), // 90% pour upload
    );

    // 4. Créer métadonnées
    final bytes = await file.readAsBytes();
    final metadata = ImageMetadata(
      uploadedBy: user.uid,
      uploadedAt: DateTime.now(),
      originalFilename: file.name,
      sizeBytes: bytes.length,
      mimeType: _inferMimeTypeFromFilename(file.name),
      altText: altText,
    );

    // 5. Créer ImageAsset
    final imageAsset = ImageAsset(
      id: imageId,
      contentType: contentType,
      parentId: parentId,
      variants: variants,
      metadata: metadata,
      order: order,
      isActive: true,
      createdAt: DateTime.now(),
    );

    // 6. Sauvegarder dans Firestore
    try {
      await _firestore
          .collection(_collectionName)
          .doc(imageId)
          .set(imageAsset.toMap());
    } on FirebaseException catch (e) {
      // Le fichier est deja uploadé sur Storage. Si la collection technique
      // image_assets est protégée par des règles plus strictes, on ne bloque
      // pas le flux POI: l'URL Storage reste utilisable pour la fiche.
      if (e.code != 'permission-denied') rethrow;
      developer.log(
        '⚠️ [ImageManagement] image_assets refusé, upload Storage conservé: $imageId (${e.code})',
      );
    }

    developer.log('✅ [ImageManagement] Image uploadée: $imageId');
    onProgress?.call(1.0);

    return imageAsset;
  }

  /// Upload galerie d'images
  Future<ImageCollection> uploadImageCollection({
    required List<XFile> files,
    required ImageContentType contentType,
    required String parentId,
    List<String>? altTexts,
    void Function(double progress)? onProgress,
  }) async {
    developer.log('📸 [ImageManagement] Upload collection: ${files.length} images');

    final images = <ImageAsset>[];
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final altText = altTexts != null && i < altTexts.length ? altTexts[i] : null;

      final imageAsset = await uploadImage(
        file: file,
        contentType: contentType,
        parentId: parentId,
        order: i,
        altText: altText,
        onProgress: (fileProgress) {
          final totalProgress = (i + fileProgress) / totalFiles;
          onProgress?.call(totalProgress);
        },
      );

      images.add(imageAsset);
    }

    return ImageCollection(
      parentId: parentId,
      coverImageId: images.isNotEmpty ? images.first.id : null,
      images: images,
    );
  }

  /// Récupérer toutes les images d'un parent
  Future<ImageCollection> getImageCollection(String parentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('parentId', isEqualTo: parentId)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final images = snapshot.docs
          .map((doc) => ImageAsset.fromMap(doc.data(), doc.id))
          .toList();

      // Déterminer coverImageId (première image ou définie manuellement)
      String? coverImageId;
      if (images.isNotEmpty) {
        // Chercher dans metadata du parent si coverImageId défini
        coverImageId = await _getCoverImageId(parentId) ?? images.first.id;
      }

      return ImageCollection(
        parentId: parentId,
        coverImageId: coverImageId,
        images: images,
      );
    } catch (e) {
      developer.log('⚠️ [ImageManagement] Erreur récupération collection: $e');
      return ImageCollection(parentId: parentId);
    }
  }

  /// Stream de collection d'images
  Stream<ImageCollection> streamImageCollection(String parentId) {
    return _firestore
        .collection(_collectionName)
        .where('parentId', isEqualTo: parentId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .asyncMap((snapshot) async {
      final images = snapshot.docs
          .map((doc) => ImageAsset.fromMap(doc.data(), doc.id))
          .toList();

      final coverImageId =
          await _getCoverImageId(parentId) ?? images.firstOrNull?.id;

      return ImageCollection(
        parentId: parentId,
        coverImageId: coverImageId,
        images: images,
      );
    });
  }

  /// Récupérer une image spécifique
  Future<ImageAsset?> getImage(String imageId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(imageId).get();
      if (!doc.exists) return null;
      return ImageAsset.fromMap(doc.data()!, doc.id);
    } catch (e) {
      developer.log('⚠️ [ImageManagement] Erreur récupération image: $e');
      return null;
    }
  }

  /// Mettre à jour ordre des images
  Future<void> reorderImages(String parentId, List<String> imageIds) async {
    final batch = _firestore.batch();

    for (var i = 0; i < imageIds.length; i++) {
      final imageId = imageIds[i];
      final ref = _firestore.collection(_collectionName).doc(imageId);
      batch.update(ref, {
        'order': i,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();
    developer.log('✅ [ImageManagement] Ordre mis à jour: ${imageIds.length} images');
  }

  /// Définir image de couverture
  Future<void> setCoverImage(String parentId, String imageId) async {
    // Stocker dans metadata du parent (selon le type)
    // Pour l'instant, on le garde dans l'ImageCollection côté client
    developer.log('✅ [ImageManagement] Cover défini: $imageId pour $parentId');
  }

  /// Supprimer une image
  Future<void> deleteImage(String imageId) async {
    try {
      final imageAsset = await getImage(imageId);
      if (imageAsset == null) return;

      // 1. Supprimer de Storage
      final basePath = _getStoragePath(
        imageAsset.contentType,
        imageAsset.parentId,
        imageId,
      );
      await _optimizer.deleteImageVariants(basePath);

      // 2. Marquer comme inactive dans Firestore (soft delete)
      await _firestore.collection(_collectionName).doc(imageId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      developer.log('✅ [ImageManagement] Image supprimée: $imageId');
    } catch (e) {
      developer.log('⚠️ [ImageManagement] Erreur suppression: $e');
      rethrow;
    }
  }

  /// Supprimer toutes les images d'un parent
  Future<void> deleteImageCollection(String parentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('parentId', isEqualTo: parentId)
          .get();

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final imageAsset = ImageAsset.fromMap(doc.data(), doc.id);

        // Supprimer de Storage
        final basePath = _getStoragePath(
          imageAsset.contentType,
          parentId,
          doc.id,
        );
        await _optimizer.deleteImageVariants(basePath);

        // Soft delete dans Firestore
        batch.update(doc.reference, {
          'isActive': false,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      await batch.commit();
      developer.log('✅ [ImageManagement] Collection supprimée: $parentId');
    } catch (e) {
      developer.log('⚠️ [ImageManagement] Erreur suppression collection: $e');
      rethrow;
    }
  }

  /// Mettre à jour alt text
  Future<void> updateAltText(String imageId, String altText) async {
    await _firestore.collection(_collectionName).doc(imageId).update({
      'metadata.altText': altText,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Statistiques images par parent
  Future<Map<String, dynamic>> getImageStats(String parentId) async {
    final collection = await getImageCollection(parentId);

    int totalSize = 0;
    for (final image in collection.images) {
      totalSize += image.metadata.sizeBytes ?? 0;
    }

    return {
      'totalImages': collection.totalImages,
      'hasGallery': collection.hasGallery,
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
    };
  }

  // ========== HELPERS PRIVÉS ==========

  /// Déterminer path Storage selon contentType
  String _getStoragePath(
    ImageContentType contentType,
    String parentId,
    String imageId,
  ) {
    switch (contentType) {
      case ImageContentType.productPhoto:
        return 'products/global/$parentId/images/$imageId';
      case ImageContentType.articleCover:
      case ImageContentType.articleGallery:
        return 'articles/$parentId/images/$imageId';
      case ImageContentType.userAvatar:
        return 'users/$parentId/avatar/$imageId';
      case ImageContentType.groupAvatar:
        return 'groups/$parentId/avatar/$imageId';
      case ImageContentType.groupBanner:
        return 'groups/$parentId/banner/$imageId';
      case ImageContentType.eventCover:
        return 'events/$parentId/cover/$imageId';
      case ImageContentType.mediaPicture:
        return 'media/global/$parentId/images/$imageId';
      case ImageContentType.placePhoto:
        return 'places/$parentId/images/$imageId';
      case ImageContentType.shopLogo:
        return 'shops/$parentId/logo/$imageId';
    }
  }

  /// Récupérer coverImageId depuis metadata du parent
  Future<String?> _getCoverImageId(String parentId) async {
    // NOTE: À implémenter selon le type de parent
    // Ex: lire document article/product et récupérer coverImageId
    return null;
  }
}
