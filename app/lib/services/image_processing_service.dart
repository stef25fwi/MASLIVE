import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../models/image_models.dart';
import 'dart:math' as math;

/// Service de traitement d'images
/// Gère resize, compression, optimisation
class ImageProcessingService {
  static final ImageProcessingService instance = ImageProcessingService._internal();
  ImageProcessingService._internal();

  /// Tailles cibles pour chaque variante
  static const Map<ImageSize, int> _targetSizes = {
    ImageSize.large: 1200,
    ImageSize.medium: 600,
    ImageSize.thumbnail: 200,
  };

  /// Traite une image et génère toutes les variantes
  Future<Map<ImageSize, Uint8List>> processImage({
    required XFile file,
    required ImageUploadConfig config,
    void Function(double progress, String step)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Lecture du fichier...');

    // 1. Lire l'image originale
    final bytes = await file.readAsBytes();
    onProgress?.call(0.2, 'Décodage de l\'image...');

    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      throw Exception('Impossible de décoder l\'image');
    }

    onProgress?.call(0.3, 'Analyse de l\'image...');

    // 2. Extraire métadonnées
    final metadata = _extractMetadata(originalImage, file.name);
    developer.log(
      "📊 Image: ${metadata['width']}x${metadata['height']}, ${metadata['sizeBytes']} bytes",
    );

    final results = <ImageSize, Uint8List>{};

    // 3. Traiter l'original
    onProgress?.call(0.4, 'Optimisation de l\'original...');
    final processedOriginal = _optimizeImage(
      originalImage,
      quality: config.quality,
      maxSize: 3840, // 4K max
    );
    results[ImageSize.original] = _encodeJpeg(processedOriginal, config.quality);

    if (config.generateVariants) {
      // 4. Générer large
      onProgress?.call(0.5, 'Génération version large...');
      final largeImage = _resizeImage(processedOriginal, _targetSizes[ImageSize.large]!);
      results[ImageSize.large] = _encodeJpeg(largeImage, config.quality);

      // 5. Générer medium
      onProgress?.call(0.7, 'Génération version medium...');
      final mediumImage = _resizeImage(processedOriginal, _targetSizes[ImageSize.medium]!);
      results[ImageSize.medium] = _encodeJpeg(mediumImage, config.quality);

      // 6. Générer thumbnail
      onProgress?.call(0.9, 'Génération miniature...');
      final thumbnailImage = _resizeImage(processedOriginal, _targetSizes[ImageSize.thumbnail]!);
      results[ImageSize.thumbnail] = _encodeJpeg(thumbnailImage, math.max(config.quality - 5, 75));
    }

    onProgress?.call(1.0, 'Traitement terminé');

    // Logs de compression
    for (final entry in results.entries) {
      final sizeKb = (entry.value.lengthInBytes / 1024).toStringAsFixed(1);
      developer.log('✅ ${entry.key.name}: $sizeKb KB');
    }

    return results;
  }

  /// Optimise une image (orientation, compression)
  img.Image _optimizeImage(img.Image image, {required int quality, int? maxSize}) {
    var optimized = image;

    // 1. Corriger orientation (EXIF)
    optimized = img.bakeOrientation(optimized);

    // 2. Limiter la taille max si spécifié
    if (maxSize != null) {
      final maxDim = math.max(optimized.width, optimized.height);
      if (maxDim > maxSize) {
        optimized = _resizeImage(optimized, maxSize);
      }
    }

    return optimized;
  }

  /// Redimensionne une image en gardant le ratio
  img.Image _resizeImage(img.Image image, int targetSize) {
    final width = image.width;
    final height = image.height;
    final maxDim = math.max(width, height);

    if (maxDim <= targetSize) {
      return image; // Déjà assez petite
    }

    final ratio = targetSize / maxDim;
    final newWidth = (width * ratio).round();
    final newHeight = (height * ratio).round();

    return img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic, // Meilleure qualité
    );
  }

  /// Encode en JPEG avec qualité
  Uint8List _encodeJpeg(img.Image image, int quality) {
    return Uint8List.fromList(
      img.encodeJpg(image, quality: quality),
    );
  }

  /// Extrait les métadonnées d'une image
  Map<String, dynamic> _extractMetadata(img.Image image, String filename) {
    return {
      'width': image.width,
      'height': image.height,
      'sizeBytes': image.lengthInBytes,
      'originalName': filename,
      'format': _getFormat(filename),
    };
  }

  /// Détermine le format depuis le nom de fichier
  String _getFormat(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return 'unknown';
    }
  }

  /// Ajoute un filigrane à l'image
  Future<img.Image> addWatermark(img.Image image, String watermarkText) async {
    // NOTE: Implémenter avec package flutter_image
    // Pour l'instant, retourner l'image sans modification
    return image;
  }

  /// Calcule le hash perceptuel d'une image (détection doublons)
  String calculateImageHash(img.Image image) {
    // Resize à 8x8 pour hash rapide
    final small = img.copyResize(image, width: 8, height: 8);

    // Convertir en niveaux de gris
    final grayscale = img.grayscale(small);

    // Calculer la luminosité moyenne
    int totalBrightness = 0;
    for (var y = 0; y < grayscale.height; y++) {
      for (var x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y);
        totalBrightness += pixel.r.toInt();
      }
    }
    final avgBrightness = totalBrightness / (grayscale.width * grayscale.height);

    // Créer hash binaire
    final hash = StringBuffer();
    for (var y = 0; y < grayscale.height; y++) {
      for (var x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y);
        hash.write(pixel.r > avgBrightness ? '1' : '0');
      }
    }

    return hash.toString();
  }

  /// Compare deux images (détection similarité)
  Future<double> calculateSimilarity(img.Image img1, img.Image img2) async {
    final hash1 = calculateImageHash(img1);
    final hash2 = calculateImageHash(img2);

    int differences = 0;
    for (var i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) differences++;
    }

    return 1 - (differences / hash1.length);
  }

  /// Détecte si l'image est floue
  bool isBlurry(img.Image image, {double threshold = 100.0}) {
    // Calculer la variance du laplacien (détection de netteté)
    final grayscale = img.grayscale(image);
    
    // Petit échantillon pour performance
    final sample = img.copyResize(grayscale, width: 500);
    
    // Calcul simplifié de netteté (variance des pixels)
    final pixels = <int>[];
    for (var y = 0; y < sample.height; y++) {
      for (var x = 0; x < sample.width; x++) {
        pixels.add(sample.getPixel(x, y).r.toInt());
      }
    }

    final mean = pixels.reduce((a, b) => a + b) / pixels.length;
    final variance = pixels.map((p) => math.pow(p - mean, 2)).reduce((a, b) => a + b) / pixels.length;

    return variance < threshold;
  }

  /// Valide qu'une image respecte les critères
  Future<ImageValidationResult> validateImage(
    XFile file, {
    int? minWidth,
    int? minHeight,
    int? maxSizeBytes,
    List<String>? allowedFormats,
  }) async {
    final errors = <String>[];

    // 1. Vérifier le format
    final format = _getFormat(file.name);
    if (allowedFormats != null && !allowedFormats.contains(format)) {
      errors.add('Format non autorisé: $format');
    }

    // 2. Vérifier la taille du fichier
    final bytes = await file.readAsBytes();
    if (maxSizeBytes != null && bytes.length > maxSizeBytes) {
      final maxMb = (maxSizeBytes / 1024 / 1024).toStringAsFixed(1);
      final actualMb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      errors.add('Fichier trop volumineux: $actualMb MB (max: $maxMb MB)');
    }

    // 3. Décoder et vérifier les dimensions
    final image = img.decodeImage(bytes);
    if (image == null) {
      errors.add('Impossible de décoder l\'image');
      return ImageValidationResult(isValid: false, errors: errors);
    }

    if (minWidth != null && image.width < minWidth) {
      errors.add('Largeur trop petite: ${image.width}px (min: ${minWidth}px)');
    }

    if (minHeight != null && image.height < minHeight) {
      errors.add('Hauteur trop petite: ${image.height}px (min: ${minHeight}px)');
    }

    // 4. Vérifier la netteté
    if (isBlurry(image)) {
      errors.add('Image floue détectée');
    }

    return ImageValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      width: image.width,
      height: image.height,
      sizeBytes: bytes.length,
    );
  }

  /// Convertit une image en WebP (meilleure compression)
  Future<Uint8List> convertToWebP(img.Image image, {int quality = 85}) async {
    // Note: Le package 'image' ne supporte pas encore WebP
    // Pour l'instant, retourner JPEG
    // NOTE: Utiliser un package natif pour WebP
    return _encodeJpeg(image, quality);
  }
}

/// Résultat de validation d'image
class ImageValidationResult {
  final bool isValid;
  final List<String> errors;
  final int? width;
  final int? height;
  final int? sizeBytes;

  const ImageValidationResult({
    required this.isValid,
    this.errors = const [],
    this.width,
    this.height,
    this.sizeBytes,
  });

  String get errorMessage => errors.join(', ');
}
