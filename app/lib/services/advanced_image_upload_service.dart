import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/image_models.dart';
import 'image_processing_service.dart';

/// Service avancé de gestion d'upload d'images
/// Gère traitement, upload variantes, métadonnées
class AdvancedImageUploadService {
  static final AdvancedImageUploadService instance = AdvancedImageUploadService._internal();
  AdvancedImageUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImageProcessingService _processor = ImageProcessingService.instance;

  User? get _currentUser => _auth.currentUser;

  /// Upload une image complète avec toutes les variantes
  Future<ImageUploadResult> uploadImage({
    required XFile file,
    required String basePath,
    required String imageId,
    required ImageUploadConfig config,
    String? alt,
    String? caption,
    int order = 0,
    void Function(double progress, String step)? onProgress,
  }) async {
    final startTime = DateTime.now();

    try {
      onProgress?.call(0.0, 'Validation...');

      // 1. Valider l'image
      final validation = await _processor.validateImage(
        file,
        minWidth: 200,
        minHeight: 200,
        maxSizeBytes: 10 * 1024 * 1024, // 10 MB max
        allowedFormats: ['jpeg', 'jpg', 'png'],
      );

      if (!validation.isValid) {
        throw Exception('Validation échouée: ${validation.errorMessage}');
      }

      onProgress?.call(0.1, 'Traitement...');

      // 2. Traiter l'image et générer variantes
      final variants = await _processor.processImage(
        file: file,
        config: config,
        onProgress: (progress, step) {
          // Progress 0.1 → 0.4 pour le traitement
          onProgress?.call(0.1 + (progress * 0.3), step);
        },
      );

      onProgress?.call(0.4, 'Upload des variantes...');

      // 3. Upload toutes les variantes
      final variantUrls = <ImageSize, String>{};
      final variantSizes = <ImageSize, int>{};
      int uploadedCount = 0;

      for (final entry in variants.entries) {
        final size = entry.key;
        final bytes = entry.value;

        // Progress 0.4 → 0.9 pour les uploads
        final uploadProgress = 0.4 + ((uploadedCount / variants.length) * 0.5);
        onProgress?.call(uploadProgress, 'Upload ${size.name}...');

        final url = await _uploadVariant(
          bytes: bytes,
          path: '$basePath/${size.name}.jpg',
          imageId: imageId,
          size: size,
        );

        variantUrls[size] = url;
        variantSizes[size] = bytes.length;
        uploadedCount++;
      }

      onProgress?.call(0.95, 'Finalisation...');

      // 4. Créer le ManagedImage
      final managedImage = ManagedImage(
        id: imageId,
        variants: ImageVariants(
          original: variantUrls[ImageSize.original]!,
          large: variantUrls[ImageSize.large]!,
          medium: variantUrls[ImageSize.medium]!,
          thumbnail: variantUrls[ImageSize.thumbnail]!,
        ),
        metadata: ImageMetadata(
          uploadedBy: _currentUser?.uid ?? 'anonymous',
          uploadedAt: DateTime.now(),
          originalName: file.name,
          width: validation.width,
          height: validation.height,
          sizeBytes: validation.sizeBytes,
          contentType: 'image/jpeg',
        ),
        alt: alt,
        caption: caption,
        order: order,
      );

      final duration = DateTime.now().difference(startTime);
      onProgress?.call(1.0, 'Terminé');

      print('✅ Upload terminé en ${duration.inSeconds}s');
      return ImageUploadResult(
        image: managedImage,
        uploadDuration: duration,
        variantSizes: variantSizes,
      );
    } catch (e) {
      print('❌ Erreur upload: $e');
      final duration = DateTime.now().difference(startTime);
      return ImageUploadResult(
        image: ManagedImage(
          id: imageId,
          variants: const ImageVariants(
            original: '',
            large: '',
            medium: '',
            thumbnail: '',
          ),
          metadata: ImageMetadata(
            uploadedBy: _currentUser?.uid ?? 'anonymous',
            uploadedAt: DateTime.now(),
            originalName: file.name,
          ),
        ),
        uploadDuration: duration,
        error: e.toString(),
      );
    }
  }

  /// Upload une variante d'image
  Future<String> _uploadVariant({
    required Uint8List bytes,
    required String path,
    required String imageId,
    required ImageSize size,
  }) async {
    final ref = _storage.ref(path);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'imageId': imageId,
        'variant': size.name,
        'uploadedBy': _currentUser?.uid ?? 'anonymous',
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    await ref.putData(bytes, metadata);
    return await ref.getDownloadURL();
  }

  /// Upload une collection d'images (galerie)
  Future<ImageCollection> uploadImageCollection({
    required List<XFile> files,
    required String basePath,
    required ImageUploadConfig config,
    XFile? coverFile,
    List<String>? altTexts,
    List<String>? captions,
    void Function(double progress, String currentFile)? onProgress,
  }) async {
    print('📤 Upload collection: ${files.length} images');

    ManagedImage? cover;
    final gallery = <ManagedImage>[];

    // 1. Upload cover si fourni
    if (coverFile != null) {
      onProgress?.call(0.0, 'Upload cover...');

      final coverResult = await uploadImage(
        file: coverFile,
        basePath: '$basePath/cover',
        imageId: 'cover',
        config: config,
        alt: altTexts?.first,
        onProgress: (progress, step) {
          onProgress?.call(progress * 0.2, 'Cover: $step');
        },
      );

      if (coverResult.isSuccess) {
        cover = coverResult.image;
      } else {
        print('⚠️ Erreur upload cover: ${coverResult.error}');
      }
    }

    // 2. Upload galerie
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final progress = (i / files.length);
      final baseProgress = coverFile != null ? 0.2 : 0.0;
      final rangeProgress = coverFile != null ? 0.8 : 1.0;

      onProgress?.call(
        baseProgress + (progress * rangeProgress),
        'Image ${i + 1}/${files.length}',
      );

      final result = await uploadImage(
        file: file,
        basePath: '$basePath/gallery/$i',
        imageId: i.toString(),
        config: config,
        alt: altTexts?.elementAtOrNull(i),
        caption: captions?.elementAtOrNull(i),
        order: i,
        onProgress: (subProgress, step) {
          final totalProgress = baseProgress + ((progress + (subProgress / files.length)) * rangeProgress);
          onProgress?.call(totalProgress, 'Image ${i + 1}: $step');
        },
      );

      if (result.isSuccess) {
        gallery.add(result.image);
        print('✅ Image ${i + 1}/${files.length} uploadée');
      } else {
        print('⚠️ Erreur image ${i + 1}: ${result.error}');
      }
    }

    onProgress?.call(1.0, 'Terminé');

    return ImageCollection(
      cover: cover,
      gallery: gallery,
      totalCount: gallery.length + (cover != null ? 1 : 0),
    );
  }

  /// Upload image pour un article
  Future<ImageCollection> uploadArticleImages({
    required String articleId,
    required List<XFile> files,
    XFile? coverFile,
    List<String>? altTexts,
    void Function(double progress, String step)? onProgress,
  }) async {
    return uploadImageCollection(
      files: files,
      basePath: 'articles/$articleId',
      config: ImageUploadConfig.article,
      coverFile: coverFile,
      altTexts: altTexts,
      onProgress: onProgress,
    );
  }

  /// Upload image pour un produit
  Future<ImageCollection> uploadProductImages({
    required String productId,
    required List<XFile> files,
    String shopId = 'global',
    XFile? coverFile,
    List<String>? altTexts,
    void Function(double progress, String step)? onProgress,
  }) async {
    return uploadImageCollection(
      files: files,
      basePath: 'products/$shopId/$productId',
      config: ImageUploadConfig.product,
      coverFile: coverFile,
      altTexts: altTexts,
      onProgress: onProgress,
    );
  }

  /// Upload avatar utilisateur
  Future<ImageUploadResult> uploadUserAvatar({
    required XFile file,
    String? userId,
    void Function(double progress, String step)? onProgress,
  }) async {
    final uid = userId ?? _currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    return uploadImage(
      file: file,
      basePath: 'users/$uid/avatar',
      imageId: 'avatar',
      config: ImageUploadConfig.avatar,
      onProgress: onProgress,
    );
  }

  /// Upload média groupe
  Future<ImageCollection> uploadGroupMedia({
    required String groupId,
    required List<XFile> files,
    List<String>? captions,
    void Function(double progress, String step)? onProgress,
  }) async {
    return uploadImageCollection(
      files: files,
      basePath: 'groups/$groupId/media',
      config: ImageUploadConfig.userMedia,
      captions: captions,
      onProgress: onProgress,
    );
  }

  /// Supprime une image et toutes ses variantes
  Future<void> deleteImage(String basePath, String imageId) async {
    print('🗑️ Suppression image: $basePath/$imageId');

    for (final size in ImageSize.values) {
      try {
        final ref = _storage.ref('$basePath/${size.name}.jpg');
        await ref.delete();
        print('✅ Variante ${size.name} supprimée');
      } catch (e) {
        print('⚠️ Erreur suppression ${size.name}: $e');
      }
    }
  }

  /// Supprime une collection d'images
  Future<void> deleteImageCollection(String basePath) async {
    print('🗑️ Suppression collection: $basePath');

    try {
      final ref = _storage.ref(basePath);
      final result = await ref.listAll();

      // Supprimer tous les fichiers
      for (final item in result.items) {
        await item.delete();
      }

      // Supprimer les sous-dossiers
      for (final prefix in result.prefixes) {
        await _deleteFolder(prefix);
      }

      print('✅ Collection supprimée');
    } catch (e) {
      print('❌ Erreur suppression collection: $e');
    }
  }

  /// Supprime un dossier récursivement
  Future<void> _deleteFolder(Reference folderRef) async {
    try {
      final result = await folderRef.listAll();

      for (final item in result.items) {
        await item.delete();
      }

      for (final prefix in result.prefixes) {
        await _deleteFolder(prefix);
      }
    } catch (e) {
      // Ignorer erreurs
    }
  }

  /// Obtient les métadonnées d'une image
  Future<ImageMetadata?> getImageMetadata(String path) async {
    try {
      final ref = _storage.ref(path);
      final metadata = await ref.getMetadata();

      return ImageMetadata(
        uploadedBy: metadata.customMetadata?['uploadedBy'] ?? '',
        uploadedAt: DateTime.parse(
          metadata.customMetadata?['uploadedAt'] ?? DateTime.now().toIso8601String(),
        ),
        originalName: metadata.name ?? '',
        sizeBytes: metadata.size,
        contentType: metadata.contentType,
      );
    } catch (e) {
      return null;
    }
  }

  /// Liste toutes les images d'un dossier
  Future<List<String>> listImages(String path) async {
    try {
      final ref = _storage.ref(path);
      final result = await ref.listAll();

      final urls = <String>[];
      for (final item in result.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }

      return urls;
    } catch (e) {
      return [];
    }
  }

  /// Vérifie si une image existe
  Future<bool> imageExists(String path) async {
    try {
      final ref = _storage.ref(path);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }
}
