/// Modèles pour la gestion avancée des images
/// Structure unifiée pour tous les types de contenu (articles, produits, médias)
library;

/// Variantes de taille d'une image
class ImageVariants {
  final String original; // Haute qualité (max 4K)
  final String large; // 1200x1200 (détail produit)
  final String medium; // 600x600 (liste, grille)
  final String thumbnail; // 200x200 (prévisualisation)

  const ImageVariants({
    required this.original,
    required this.large,
    required this.medium,
    required this.thumbnail,
  });

  factory ImageVariants.fromMap(Map<String, dynamic> map) {
    return ImageVariants(
      original: map['original'] ?? '',
      large: map['large'] ?? '',
      medium: map['medium'] ?? '',
      thumbnail: map['thumbnail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'original': original,
        'large': large,
        'medium': medium,
        'thumbnail': thumbnail,
      };

  /// Obtient l'URL selon le type demandé
  String getUrl(ImageSize size) {
    switch (size) {
      case ImageSize.original:
        return original;
      case ImageSize.large:
        return large;
      case ImageSize.medium:
        return medium;
      case ImageSize.thumbnail:
        return thumbnail;
    }
  }

  /// Vérifie si toutes les variantes sont disponibles
  bool get isComplete =>
      original.isNotEmpty &&
      large.isNotEmpty &&
      medium.isNotEmpty &&
      thumbnail.isNotEmpty;
}

/// Tailles d'image disponibles
enum ImageSize {
  original, // 4K max
  large, // 1200px
  medium, // 600px
  thumbnail, // 200px
}

/// Métadonnées d'une image
class ImageMetadata {
  final String uploadedBy;
  final DateTime uploadedAt;
  final String originalName;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? contentType;
  final Map<String, dynamic>? exif; // Données EXIF (caméra, GPS, etc.)

  const ImageMetadata({
    required this.uploadedBy,
    required this.uploadedAt,
    required this.originalName,
    this.width,
    this.height,
    this.sizeBytes,
    this.contentType,
    this.exif,
  });

  factory ImageMetadata.fromMap(Map<String, dynamic> map) {
    return ImageMetadata(
      uploadedBy: map['uploadedBy'] ?? '',
      uploadedAt: DateTime.parse(map['uploadedAt'] ?? DateTime.now().toIso8601String()),
      originalName: map['originalName'] ?? '',
      width: map['width'],
      height: map['height'],
      sizeBytes: map['sizeBytes'],
      contentType: map['contentType'],
      exif: map['exif'],
    );
  }

  Map<String, dynamic> toMap() => {
        'uploadedBy': uploadedBy,
        'uploadedAt': uploadedAt.toIso8601String(),
        'originalName': originalName,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (contentType != null) 'contentType': contentType,
        if (exif != null) 'exif': exif,
      };
}

/// Image complète avec variantes et métadonnées
class ManagedImage {
  final String id;
  final ImageVariants variants;
  final ImageMetadata metadata;
  final String? alt; // Texte alternatif (SEO, accessibilité)
  final String? caption; // Légende
  final int order; // Ordre d'affichage
  final Map<String, dynamic>? customData; // Données personnalisées

  const ManagedImage({
    required this.id,
    required this.variants,
    required this.metadata,
    this.alt,
    this.caption,
    this.order = 0,
    this.customData,
  });

  factory ManagedImage.fromMap(Map<String, dynamic> map, String id) {
    return ManagedImage(
      id: id,
      variants: ImageVariants.fromMap(map['variants'] ?? map),
      metadata: ImageMetadata.fromMap(map['metadata'] ?? {}),
      alt: map['alt'],
      caption: map['caption'],
      order: map['order'] ?? 0,
      customData: map['customData'],
    );
  }

  Map<String, dynamic> toMap() => {
        'variants': variants.toMap(),
        'metadata': metadata.toMap(),
        if (alt != null) 'alt': alt,
        if (caption != null) 'caption': caption,
        'order': order,
        if (customData != null) 'customData': customData,
      };

  /// Obtient l'URL selon la taille
  String getUrl(ImageSize size) => variants.getUrl(size);

  /// URL par défaut (medium)
  String get url => variants.medium;

  /// Crée une copie avec modifications
  ManagedImage copyWith({
    String? id,
    ImageVariants? variants,
    ImageMetadata? metadata,
    String? alt,
    String? caption,
    int? order,
    Map<String, dynamic>? customData,
  }) {
    return ManagedImage(
      id: id ?? this.id,
      variants: variants ?? this.variants,
      metadata: metadata ?? this.metadata,
      alt: alt ?? this.alt,
      caption: caption ?? this.caption,
      order: order ?? this.order,
      customData: customData ?? this.customData,
    );
  }
}

/// Collection d'images pour un contenu
class ImageCollection {
  final ManagedImage? cover; // Image de couverture
  final List<ManagedImage> gallery; // Galerie d'images
  final int totalCount;

  const ImageCollection({
    this.cover,
    this.gallery = const [],
    int? totalCount,
  }) : totalCount = totalCount ?? gallery.length;

  factory ImageCollection.fromMap(Map<String, dynamic> map) {
    return ImageCollection(
      cover: map['cover'] != null
          ? ManagedImage.fromMap(map['cover'], 'cover')
          : null,
      gallery: (map['gallery'] as List?)
              ?.asMap()
              .entries
              .map((e) => ManagedImage.fromMap(e.value, e.key.toString()))
              .toList() ??
          [],
      totalCount: map['totalCount'],
    );
  }

  Map<String, dynamic> toMap() => {
        if (cover != null) 'cover': cover!.toMap(),
        'gallery': gallery.map((e) => e.toMap()).toList(),
        'totalCount': totalCount,
      };

  /// Obtient toutes les images (cover + gallery)
  List<ManagedImage> get allImages {
    final images = <ManagedImage>[];
    if (cover != null) images.add(cover!);
    images.addAll(gallery);
    return images;
  }

  /// Vérifie si la collection a des images
  bool get hasImages => cover != null || gallery.isNotEmpty;

  /// Obtient l'image par défaut
  ManagedImage? get defaultImage => cover ?? (gallery.isNotEmpty ? gallery.first : null);

  /// Obtient une image par ID
  ManagedImage? getById(String id) {
    if (cover?.id == id) return cover;
    try {
      return gallery.firstWhere((img) => img.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Crée une copie avec modifications
  ImageCollection copyWith({
    ManagedImage? cover,
    List<ManagedImage>? gallery,
    int? totalCount,
  }) {
    return ImageCollection(
      cover: cover ?? this.cover,
      gallery: gallery ?? this.gallery,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  /// Ajoute une image à la galerie
  ImageCollection addToGallery(ManagedImage image) {
    return copyWith(
      gallery: [...gallery, image],
      totalCount: totalCount + 1,
    );
  }

  /// Supprime une image de la galerie
  ImageCollection removeFromGallery(String imageId) {
    return copyWith(
      gallery: gallery.where((img) => img.id != imageId).toList(),
      totalCount: totalCount - 1,
    );
  }

  /// Réordonne la galerie
  ImageCollection reorderGallery(List<String> newOrder) {
    final reordered = <ManagedImage>[];
    for (var i = 0; i < newOrder.length; i++) {
      final img = getById(newOrder[i]);
      if (img != null) {
        reordered.add(img.copyWith(order: i));
      }
    }
    return copyWith(gallery: reordered);
  }
}

/// Configuration d'upload d'image
class ImageUploadConfig {
  final ImageSize maxSize; // Taille max de l'original
  final int quality; // Qualité JPEG (1-100)
  final bool generateVariants; // Générer automatiquement les variantes
  final bool preserveExif; // Conserver les données EXIF
  final String? watermark; // Filigrane à appliquer
  final List<ImageSize> requiredSizes; // Tailles requises

  const ImageUploadConfig({
    this.maxSize = ImageSize.original,
    this.quality = 85,
    this.generateVariants = true,
    this.preserveExif = false,
    this.watermark,
    this.requiredSizes = const [
      ImageSize.original,
      ImageSize.large,
      ImageSize.medium,
      ImageSize.thumbnail,
    ],
  });

  /// Configuration par défaut pour articles
  static const ImageUploadConfig article = ImageUploadConfig(
    quality: 90,
    generateVariants: true,
    preserveExif: false,
  );

  /// Configuration par défaut pour produits
  static const ImageUploadConfig product = ImageUploadConfig(
    quality: 85,
    generateVariants: true,
    preserveExif: false,
  );

  /// Configuration par défaut pour médias utilisateur
  static const ImageUploadConfig userMedia = ImageUploadConfig(
    quality: 80,
    generateVariants: true,
    preserveExif: true, // Garder GPS, date, etc.
  );

  /// Configuration par défaut pour avatars
  static const ImageUploadConfig avatar = ImageUploadConfig(
    quality: 85,
    generateVariants: true,
    preserveExif: false,
    requiredSizes: [ImageSize.large, ImageSize.medium, ImageSize.thumbnail],
  );
}

/// Résultat d'un upload d'image
class ImageUploadResult {
  final ManagedImage image;
  final Duration uploadDuration;
  final Map<ImageSize, int> variantSizes; // Taille en bytes de chaque variante
  final String? error;

  const ImageUploadResult({
    required this.image,
    required this.uploadDuration,
    this.variantSizes = const {},
    this.error,
  });

  bool get isSuccess => error == null;
  bool get hasError => error != null;
}
