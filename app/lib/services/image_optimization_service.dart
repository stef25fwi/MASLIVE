import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/image_asset.dart' as asset;
import 'webp_converter.dart';

enum ImageFormat {
  jpeg,
  png,
  webp;
}

/// Service d'optimisation d'images
/// Génère automatiquement les variantes de taille et optimise la compression
class ImageOptimizationService {
  static final ImageOptimizationService instance =
      ImageOptimizationService._internal();
  ImageOptimizationService._internal();

  /// Qualité JPEG par taille
  static const Map<asset.ImageSize, int> _jpegQuality = {
    asset.ImageSize.thumbnail: 75,
    asset.ImageSize.small: 80,
    asset.ImageSize.medium: 85,
    asset.ImageSize.large: 88,
    asset.ImageSize.xlarge: 90,
    asset.ImageSize.original: 92,
  };

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload (minimal) d'une image et retourne des variantes.
  ///
  /// Implémentation volontairement simple: upload de l'original uniquement,
  /// les URLs des autres tailles restent null (fallback sur original).
  Future<asset.ImageVariants> uploadImageWithVariants({
    required XFile file,
    required String basePath,
    required asset.ImageContentType contentType,
    void Function(double progress)? onProgress,
  }) async {
    var bytes = await file.readAsBytes();
    var ext = _extension(file.name);
    var mimeType = _mimeTypeForExtension(ext);

    // Conversion WebP systématique (allègement), cohérente avec StorageService.
    // On ne conserve le WebP que s'il est réellement plus léger que l'original.
    if (supportsWebpConversion &&
        (ext == 'jpg' || ext == 'jpeg' || ext == 'png')) {
      try {
        // Borne globale de sécurité: la conversion ne doit JAMAIS bloquer
        // l'upload. En cas d'expiration (ex: Safari qui n'émet pas onLoad),
        // on retombe sur les octets d'origine et on poursuit l'envoi.
        final webpBytes = await convertBytesToWebp(bytes, quality: 82)
            .timeout(const Duration(seconds: 12));
        if (webpBytes.length < bytes.length) {
          bytes = webpBytes;
          ext = 'webp';
          mimeType = 'image/webp';
        }
      } catch (e) {
        developer.log('⚠️ [ImageOptimization] WebP ignoré: $e');
      }
    }

    final objectPath = '$basePath/original.$ext';
    final ref = _storage.ref(objectPath);
    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'contentType': contentType.label,
          'originalFilename': file.name,
        },
      ),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        if (total <= 0) return;
        onProgress(snapshot.bytesTransferred / total);
      });
    }

    await uploadTask;
    final url = await ref.getDownloadURL();

    return asset.ImageVariants(
      original: url,
    );
  }

  /// Supprime toutes les variantes sous un chemin (dossier) donné.
  Future<void> deleteImageVariants(String basePath) async {
    final ref = _storage.ref(basePath);
    await _deleteFolderRecursive(ref);
  }

  Future<void> _deleteFolderRecursive(Reference ref) async {
    final list = await ref.listAll();

    for (final item in list.items) {
      await item.delete();
    }

    for (final prefix in list.prefixes) {
      await _deleteFolderRecursive(prefix);
    }
  }

  /// Générer toutes les variantes d'une image
  Future<Map<asset.ImageSize, Uint8List>> generateVariants({
    required Uint8List originalBytes,
    ImageFormat format = ImageFormat.jpeg,
    List<asset.ImageSize> sizes = const [
      asset.ImageSize.thumbnail,
      asset.ImageSize.small,
      asset.ImageSize.medium,
      asset.ImageSize.large,
      asset.ImageSize.xlarge,
      asset.ImageSize.original,
    ],
  }) async {
    developer.log('🎨 [ImageOptimization] Début génération variantes...');

    // Décoder l'image originale
    final img.Image? original = img.decodeImage(originalBytes);
    if (original == null) {
      throw Exception('Impossible de décoder l\'image');
    }

    developer.log(
      '✅ [ImageOptimization] Image décodée: ${original.width}x${original.height}',
    );

    final variants = <asset.ImageSize, Uint8List>{};

    for (final size in sizes) {
      try {
        final bytes = await _generateVariant(
          original: original,
          size: size,
          format: format,
        );
        variants[size] = bytes;
        developer.log(
          '✅ [ImageOptimization] Variante ${size.name}: ${bytes.length} bytes',
        );
      } catch (e) {
        developer.log('❌ [ImageOptimization] Erreur variante ${size.name}: $e');
      }
    }

    return variants;
  }

  /// Générer une variante spécifique
  Future<Uint8List> _generateVariant({
    required img.Image original,
    required asset.ImageSize size,
    required ImageFormat format,
  }) async {
    // Si c'est l'original, juste réencoder avec qualité optimale
    if (size == asset.ImageSize.original) {
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
      interpolation: img.Interpolation.cubic,
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
      developer.log(
        '🔄 [ImageOptimization] Compression Q$quality: ${compressed.length} bytes',
      );
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

  String _extension(String filename) {
    final parts = filename.toLowerCase().split('.');
    if (parts.length < 2) return 'jpg';
    final ext = parts.last;
    if (ext == 'jpeg') return 'jpg';
    if (ext == 'jpg' || ext == 'png' || ext == 'webp') return ext;
    return 'jpg';
  }

  String _mimeTypeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      default:
        return 'image/jpeg';
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
}
