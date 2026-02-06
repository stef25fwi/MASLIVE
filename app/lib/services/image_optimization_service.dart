import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../models/optimized_image.dart';

/// Service d'optimisation d'images
/// Génère automatiquement les variantes de taille et optimise la compression
class ImageOptimizationService {
  static final ImageOptimizationService instance =
      ImageOptimizationService._internal();
  ImageOptimizationService._internal();

  /// Qualité JPEG par taille
  static const Map<ImageSize, int> _jpegQuality = {
    ImageSize.thumbnail: 75,
    ImageSize.small: 80,
    ImageSize.medium: 85,
    ImageSize.large: 88,
    ImageSize.original: 92,
  };

  /// Générer toutes les variantes d'une image
  Future<Map<ImageSize, Uint8List>> generateVariants({
    required Uint8List originalBytes,
    ImageFormat format = ImageFormat.jpeg,
    List<ImageSize> sizes = const [
      ImageSize.thumbnail,
      ImageSize.small,
      ImageSize.medium,
      ImageSize.large,
      ImageSize.original,
    ],
  }) async {
    print('🎨 [ImageOptimization] Début génération variantes...');

    // Décoder l'image originale
    final img.Image? original = img.decodeImage(originalBytes);
    if (original == null) {
      throw Exception('Impossible de décoder l\'image');
    }

    print('✅ [ImageOptimization] Image décodée: ${original.width}x${original.height}');

    final variants = <ImageSize, Uint8List>{};

    for (final size in sizes) {
      try {
        final bytes = await _generateVariant(
          original: original,
          size: size,
          format: format,
        );
        variants[size] = bytes;
        print(
            '✅ [ImageOptimization] Variante ${size.name}: ${bytes.length} bytes');
      } catch (e) {
        print('❌ [ImageOptimization] Erreur variante ${size.name}: $e');
      }
    }

    return variants;
  }

  /// Générer une variante spécifique
  Future<Uint8List> _generateVariant({
    required img.Image original,
    required ImageSize size,
    required ImageFormat format,
  }) async {
    // Si c'est l'original, juste réencoder avec qualité optimale
    if (size == ImageSize.original) {
      return _encodeImage(original, format, _jpegQuality[size]!);
    }

    // Calculer les nouvelles dimensions en gardant le ratio
    final maxDim = size.maxDimension;
    final originalWidth = original.width;
    final originalHeight = original.height;

    // Si l'image est déjà plus petite, ne pas agrandir
    if (originalWidth <= maxDim && originalHeight <= maxDim) {
      return _encodeImage(original, format, _jpegQuality[size]!);
    }

    int newWidth, newHeight;
    if (originalWidth > originalHeight) {
      newWidth = maxDim;
      newHeight = (maxDim * originalHeight / originalWidth).round();
    } else {
      newHeight = maxDim;
      newWidth = (maxDim * originalWidth / originalHeight).round();
    }

    // Redimensionner
    final resized = img.copyResize(
      original,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.lanczos,
    );

    // Encoder avec la bonne qualité
    return _encodeImage(resized, format, _jpegQuality[size]!);
  }

  /// Encoder une image
  Uint8List _encodeImage(
    img.Image image,
    ImageFormat format,
    int quality,
  ) {
    switch (format) {
      case ImageFormat.jpeg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ImageFormat.png:
        return Uint8List.fromList(img.encodePng(image, level: 6));
      case ImageFormat.webp:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
  }

  /// Obtenir les dimensions d'une image
  Future<Map<String, int>> getImageDimensions(Uint8List bytes) async {
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image');
    }
    return {
      'width': image.width,
      'height': image.height,
    };
  }

  /// Optimiser une image sans changer sa taille
  Future<Uint8List> optimizeImage({
    required Uint8List bytes,
    ImageFormat format = ImageFormat.jpeg,
    int quality = 85,
  }) async {
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image');
    }

    return _encodeImage(image, format, quality);
  }

  /// Compresser une image à une taille maximale en bytes
  Future<Uint8List> compressToMaxSize({
    required Uint8List bytes,
    required int maxSizeBytes,
    ImageFormat format = ImageFormat.jpeg,
    int initialQuality = 90,
  }) async {
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image');
    }

    int quality = initialQuality;
    Uint8List compressed = bytes;

    while (compressed.length > maxSizeBytes && quality > 10) {
      quality -= 10;
      compressed = _encodeImage(image, format, quality);
      print(
          '🔄 [ImageOptimization] Compression Q$quality: ${compressed.length} bytes');
    }

    if (compressed.length > maxSizeBytes) {
      // Si toujours trop gros, réduire la taille
      final scale = 0.9;
      final resized = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
      );
      compressed = _encodeImage(resized, format, quality);
    }

    return compressed;
  }

  /// Créer un thumbnail carré (crop center)
  Future<Uint8List> createSquareThumbnail({
    required Uint8List bytes,
    int size = 200,
    int quality = 80,
  }) async {
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image');
    }

    // Crop au centre pour avoir un carré
    final minDim = image.width < image.height ? image.width : image.height;
    final x = (image.width - minDim) ~/ 2;
    final y = (image.height - minDim) ~/ 2;

    final cropped = img.copyCrop(image, x: x, y: y, width: minDim, height: minDim);

    // Redimensionner au format thumbnail
    final resized = img.copyResize(cropped, width: size, height: size);

    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  /// Détecter le format d'une image
  ImageFormat detectFormat(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return ImageFormat.jpeg;
      case 'png':
        return ImageFormat.png;
      case 'webp':
        return ImageFormat.webp;
      default:
        return ImageFormat.jpeg;
    }
  }

  /// Valider qu'un fichier est une image valide
  Future<bool> isValidImage(Uint8List bytes) async {
    try {
      final img.Image? image = img.decodeImage(bytes);
      return image != null;
    } catch (e) {
      return false;
    }
  }

  /// Obtenir les métadonnées d'une image
  Future<ImageMetadata> extractMetadata({
    required Uint8List bytes,
    required String uploadedBy,
    String? altText,
    String? caption,
  }) async {
    final dimensions = await getImageDimensions(bytes);
    final format = ImageFormat.jpeg; // Détecté via extension dans le vrai cas

    return ImageMetadata(
      width: dimensions['width'],
      height: dimensions['height'],
      sizeBytes: bytes.length,
      format: format,
      uploadedAt: DateTime.now(),
      uploadedBy: uploadedBy,
      altText: altText,
      caption: caption,
    );
  }

  /// Préparer une image pour l'upload (optimisation + variantes)
  Future<Map<String, dynamic>> prepareImageForUpload({
    required XFile file,
    required String uploadedBy,
    String? altText,
    String? caption,
    List<ImageSize> sizes = const [
      ImageSize.thumbnail,
      ImageSize.small,
      ImageSize.medium,
      ImageSize.large,
      ImageSize.original,
    ],
  }) async {
    print('📸 [ImageOptimization] Préparation image: ${file.name}');

    // Lire les bytes
    final bytes = await file.readAsBytes();
    print('✅ [ImageOptimization] Fichier lu: ${bytes.length} bytes');

    // Valider
    if (!await isValidImage(bytes)) {
      throw Exception('Fichier image invalide');
    }

    // Détecter le format
    final format = detectFormat(file.name);

    // Générer variantes
    final variants = await generateVariants(
      originalBytes: bytes,
      format: format,
      sizes: sizes,
    );

    // Extraire métadonnées
    final metadata = await extractMetadata(
      bytes: bytes,
      uploadedBy: uploadedBy,
      altText: altText,
      caption: caption,
    );

    print('✅ [ImageOptimization] ${variants.length} variantes générées');
    print(
        '✅ [ImageOptimization] Dimensions: ${metadata.width}x${metadata.height}');

    return {
      'variants': variants,
      'metadata': metadata,
      'format': format,
    };
  }

  /// Calculer l'espace économisé avec l'optimisation
  Map<String, dynamic> calculateSavings({
    required int originalSize,
    required Map<ImageSize, int> variantSizes,
  }) {
    final thumbnailSize = variantSizes[ImageSize.thumbnail] ?? 0;
    final mediumSize = variantSizes[ImageSize.medium] ?? 0;

    final thumbnailSavings =
        ((1 - thumbnailSize / originalSize) * 100).toStringAsFixed(1);
    final mediumSavings =
        ((1 - mediumSize / originalSize) * 100).toStringAsFixed(1);

    return {
      'originalSize': originalSize,
      'thumbnailSize': thumbnailSize,
      'mediumSize': mediumSize,
      'thumbnailSavings': '$thumbnailSavings%',
      'mediumSavings': '$mediumSavings%',
    };
  }
}
