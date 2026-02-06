import 'package:cloud_firestore/cloud_firestore.dart';

/// Taille d'image prédéfinie
enum ImageSize {
  thumbnail, // 200x200
  small, // 400x400
  medium, // 800x800
  large, // 1200x1200
  original; // Taille originale

  int get maxDimension {
    switch (this) {
      case ImageSize.thumbnail:
        return 200;
      case ImageSize.small:
        return 400;
      case ImageSize.medium:
        return 800;
      case ImageSize.large:
        return 1200;
      case ImageSize.original:
        return 4000;
    }
  }

  String get suffix {
    switch (this) {
      case ImageSize.thumbnail:
        return '_thumb';
      case ImageSize.small:
        return '_small';
      case ImageSize.medium:
        return '_medium';
      case ImageSize.large:
        return '_large';
      case ImageSize.original:
        return '_original';
    }
  }
}

/// Format d'image supporté
enum ImageFormat {
  jpeg,
  png,
  webp;

  String get extension {
    switch (this) {
      case ImageFormat.jpeg:
        return 'jpg';
      case ImageFormat.png:
        return 'png';
      case ImageFormat.webp:
        return 'webp';
    }
  }

  String get mimeType {
    switch (this) {
      case ImageFormat.jpeg:
        return 'image/jpeg';
      case ImageFormat.png:
        return 'image/png';
      case ImageFormat.webp:
        return 'image/webp';
    }
  }
}

/// Variantes d'une image (différentes tailles)
class ImageVariants {
  final String thumbnail;
  final String small;
  final String medium;
  final String large;
  final String original;

  const ImageVariants({
    required this.thumbnail,
    required this.small,
    required this.medium,
    required this.large,
    required this.original,
  });

  /// Obtenir l'URL selon la taille demandée
  String getUrl(ImageSize size) {
    switch (size) {
      case ImageSize.thumbnail:
        return thumbnail;
      case ImageSize.small:
        return small;
      case ImageSize.medium:
        return medium;
      case ImageSize.large:
        return large;
      case ImageSize.original:
        return original;
    }
  }

  /// Obtenir la meilleure URL pour une largeur donnée
  String getBestUrl(double width) {
    if (width <= 200) return thumbnail;
    if (width <= 400) return small;
    if (width <= 800) return medium;
    if (width <= 1200) return large;
    return original;
  }

  factory ImageVariants.fromMap(Map<String, dynamic> map) {
    return ImageVariants(
      thumbnail: map['thumbnail'] ?? map['original'] ?? '',
      small: map['small'] ?? map['medium'] ?? map['original'] ?? '',
      medium: map['medium'] ?? map['original'] ?? '',
      large: map['large'] ?? map['original'] ?? '',
      original: map['original'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'thumbnail': thumbnail,
        'small': small,
        'medium': medium,
        'large': large,
        'original': original,
      };

  factory ImageVariants.fromJson(Map<String, dynamic> json) =>
      ImageVariants.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Créer depuis une seule URL (fallback)
  factory ImageVariants.fromSingleUrl(String url) {
    return ImageVariants(
      thumbnail: url,
      small: url,
      medium: url,
      large: url,
      original: url,
    );
  }

  bool get isValid => original.isNotEmpty;
}

/// Métadonnées d'une image
class ImageMetadata {
  final int? width;
  final int? height;
  final int? sizeBytes;
  final ImageFormat format;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String? altText;
  final String? caption;
  final Map<String, dynamic>? exif;

  const ImageMetadata({
    this.width,
    this.height,
    this.sizeBytes,
    required this.format,
    required this.uploadedAt,
    required this.uploadedBy,
    this.altText,
    this.caption,
    this.exif,
  });

  double? get aspectRatio {
    if (width != null && height != null && height! > 0) {
      return width! / height!;
    }
    return null;
  }

  factory ImageMetadata.fromMap(Map<String, dynamic> map) {
    return ImageMetadata(
      width: map['width'],
      height: map['height'],
      sizeBytes: map['sizeBytes'],
      format: ImageFormat.values.firstWhere(
        (f) => f.extension == map['format'],
        orElse: () => ImageFormat.jpeg,
      ),
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploadedBy: map['uploadedBy'] ?? '',
      altText: map['altText'],
      caption: map['caption'],
      exif: map['exif'],
    );
  }

  Map<String, dynamic> toMap() => {
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        'format': format.extension,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
        'uploadedBy': uploadedBy,
        if (altText != null) 'altText': altText,
        if (caption != null) 'caption': caption,
        if (exif != null) 'exif': exif,
      };
}

/// Image complète avec toutes ses variantes et métadonnées
class OptimizedImage {
  final String id;
  final ImageVariants variants;
  final ImageMetadata metadata;
  final int order;

  const OptimizedImage({
    required this.id,
    required this.variants,
    required this.metadata,
    this.order = 0,
  });

  /// URL par défaut (medium)
  String get url => variants.medium;

  /// URL thumbnail
  String get thumbnailUrl => variants.thumbnail;

  /// URL original
  String get originalUrl => variants.original;

  /// Texte alternatif
  String get alt => metadata.altText ?? '';

  factory OptimizedImage.fromMap(Map<String, dynamic> map, {String? id}) {
    return OptimizedImage(
      id: id ?? map['id'] ?? '',
      variants: ImageVariants.fromMap(map['variants'] ?? map),
      metadata: ImageMetadata.fromMap(map['metadata'] ?? {}),
      order: map['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'variants': variants.toMap(),
        'metadata': metadata.toMap(),
        'order': order,
      };

  factory OptimizedImage.fromJson(Map<String, dynamic> json) =>
      OptimizedImage.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  OptimizedImage copyWith({
    String? id,
    ImageVariants? variants,
    ImageMetadata? metadata,
    int? order,
  }) {
    return OptimizedImage(
      id: id ?? this.id,
      variants: variants ?? this.variants,
      metadata: metadata ?? this.metadata,
      order: order ?? this.order,
    );
  }
}

/// Collection d'images (cover + galerie)
class ImageCollection {
  final OptimizedImage? cover;
  final List<OptimizedImage> gallery;

  const ImageCollection({
    this.cover,
    this.gallery = const [],
  });

  bool get hasCover => cover != null;
  bool get hasGallery => gallery.isNotEmpty;
  int get galleryCount => gallery.length;
  int get totalCount => (hasCover ? 1 : 0) + galleryCount;

  /// Obtenir toutes les images (cover + galerie)
  List<OptimizedImage> get allImages {
    final all = <OptimizedImage>[];
    if (cover != null) all.add(cover!);
    all.addAll(gallery);
    return all;
  }

  /// Obtenir une image par index (0 = cover, 1+ = galerie)
  OptimizedImage? getImageAt(int index) {
    if (index == 0 && cover != null) return cover;
    final galleryIndex = hasCover ? index - 1 : index;
    if (galleryIndex >= 0 && galleryIndex < gallery.length) {
      return gallery[galleryIndex];
    }
    return null;
  }

  factory ImageCollection.fromMap(Map<String, dynamic> map) {
    return ImageCollection(
      cover: map['cover'] != null
          ? OptimizedImage.fromMap(map['cover'])
          : null,
      gallery: (map['gallery'] as List?)
              ?.map((e) => OptimizedImage.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => {
        if (cover != null) 'cover': cover!.toMap(),
        'gallery': gallery.map((e) => e.toMap()).toList(),
      };

  factory ImageCollection.fromJson(Map<String, dynamic> json) =>
      ImageCollection.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Créer depuis une seule URL (migration)
  factory ImageCollection.fromSingleUrl(String url, {String? altText}) {
    if (url.isEmpty) return const ImageCollection();

    final variants = ImageVariants.fromSingleUrl(url);
    final metadata = ImageMetadata(
      format: ImageFormat.jpeg,
      uploadedAt: DateTime.now(),
      uploadedBy: 'system',
      altText: altText,
    );

    return ImageCollection(
      cover: OptimizedImage(
        id: '0',
        variants: variants,
        metadata: metadata,
      ),
    );
  }

  /// Créer depuis une liste d'URLs (migration)
  factory ImageCollection.fromUrls(
    List<String> urls, {
    String? coverUrl,
    List<String>? altTexts,
  }) {
    if (urls.isEmpty && coverUrl == null) {
      return const ImageCollection();
    }

    OptimizedImage? cover;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      cover = OptimizedImage(
        id: 'cover',
        variants: ImageVariants.fromSingleUrl(coverUrl),
        metadata: ImageMetadata(
          format: ImageFormat.jpeg,
          uploadedAt: DateTime.now(),
          uploadedBy: 'system',
          altText: altTexts?.firstOrNull,
        ),
      );
    }

    final gallery = urls
        .asMap()
        .entries
        .map((entry) => OptimizedImage(
              id: entry.key.toString(),
              variants: ImageVariants.fromSingleUrl(entry.value),
              metadata: ImageMetadata(
                format: ImageFormat.jpeg,
                uploadedAt: DateTime.now(),
                uploadedBy: 'system',
                altText: altTexts?[entry.key],
              ),
              order: entry.key,
            ))
        .toList();

    return ImageCollection(
      cover: cover,
      gallery: gallery,
    );
  }

  ImageCollection copyWith({
    OptimizedImage? cover,
    List<OptimizedImage>? gallery,
  }) {
    return ImageCollection(
      cover: cover ?? this.cover,
      gallery: gallery ?? this.gallery,
    );
  }
}
