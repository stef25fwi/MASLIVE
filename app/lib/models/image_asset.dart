import 'package:cloud_firestore/cloud_firestore.dart';

/// Taille d'image variante
enum ImageSize {
  thumbnail, // 200x200
  small, // 400x400
  medium, // 800x800
  large, // 1200x1200
  xlarge, // 1920x1920
  original; // Taille originale

  String get label {
    switch (this) {
      case ImageSize.thumbnail:
        return 'thumbnail';
      case ImageSize.small:
        return 'small';
      case ImageSize.medium:
        return 'medium';
      case ImageSize.large:
        return 'large';
      case ImageSize.xlarge:
        return 'xlarge';
      case ImageSize.original:
        return 'original';
    }
  }

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
      case ImageSize.xlarge:
        return 1920;
      case ImageSize.original:
        return 0; // Pas de limite
    }
  }
}

/// Type de contenu image
enum ImageContentType {
  productPhoto,
  articleCover,
  articleGallery,
  userAvatar,
  groupAvatar,
  groupBanner,
  eventCover,
  mediaPicture,
  placePhoto,
  shopLogo;

  String get label => name;
}

/// Variantes d'une image (toutes les tailles disponibles)
class ImageVariants {
  final String? thumbnail;
  final String? small;
  final String? medium;
  final String? large;
  final String? xlarge;
  final String original;

  ImageVariants({
    this.thumbnail,
    this.small,
    this.medium,
    this.large,
    this.xlarge,
    required this.original,
  });

  /// Obtenir la meilleure URL selon la taille demandée
  String getUrl(ImageSize size) {
    switch (size) {
      case ImageSize.thumbnail:
        return thumbnail ?? small ?? medium ?? original;
      case ImageSize.small:
        return small ?? medium ?? original;
      case ImageSize.medium:
        return medium ?? large ?? original;
      case ImageSize.large:
        return large ?? xlarge ?? original;
      case ImageSize.xlarge:
        return xlarge ?? original;
      case ImageSize.original:
        return original;
    }
  }

  /// Obtenir URL adaptative selon largeur écran
  String getResponsiveUrl(double screenWidth) {
    if (screenWidth <= 300) return getUrl(ImageSize.thumbnail);
    if (screenWidth <= 600) return getUrl(ImageSize.small);
    if (screenWidth <= 1024) return getUrl(ImageSize.medium);
    if (screenWidth <= 1920) return getUrl(ImageSize.large);
    return getUrl(ImageSize.xlarge);
  }

  factory ImageVariants.fromMap(Map<String, dynamic> map) {
    return ImageVariants(
      thumbnail: map['thumbnail'],
      small: map['small'],
      medium: map['medium'],
      large: map['large'],
      xlarge: map['xlarge'],
      original: map['original'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'original': original,
    };
    if (thumbnail != null) map['thumbnail'] = thumbnail;
    if (small != null) map['small'] = small;
    if (medium != null) map['medium'] = medium;
    if (large != null) map['large'] = large;
    if (xlarge != null) map['xlarge'] = xlarge;
    return map;
  }

  ImageVariants copyWith({
    String? thumbnail,
    String? small,
    String? medium,
    String? large,
    String? xlarge,
    String? original,
  }) {
    return ImageVariants(
      thumbnail: thumbnail ?? this.thumbnail,
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
      xlarge: xlarge ?? this.xlarge,
      original: original ?? this.original,
    );
  }
}

/// Métadonnées d'une image
class ImageMetadata {
  final String uploadedBy;
  final DateTime uploadedAt;
  final String originalFilename;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? mimeType;
  final String? altText;
  final Map<String, dynamic>? exif;

  ImageMetadata({
    required this.uploadedBy,
    required this.uploadedAt,
    required this.originalFilename,
    this.width,
    this.height,
    this.sizeBytes,
    this.mimeType,
    this.altText,
    this.exif,
  });

  factory ImageMetadata.fromMap(Map<String, dynamic> map) {
    return ImageMetadata(
      uploadedBy: map['uploadedBy'] ?? '',
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      originalFilename: map['originalFilename'] ?? '',
      width: map['width'],
      height: map['height'],
      sizeBytes: map['sizeBytes'],
      mimeType: map['mimeType'],
      altText: map['altText'],
      exif: map['exif'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'originalFilename': originalFilename,
    };
    if (width != null) map['width'] = width;
    if (height != null) map['height'] = height;
    if (sizeBytes != null) map['sizeBytes'] = sizeBytes;
    if (mimeType != null) map['mimeType'] = mimeType;
    if (altText != null) map['altText'] = altText;
    if (exif != null) map['exif'] = exif;
    return map;
  }
}

/// Modèle unifié pour toute image dans l'application
class ImageAsset {
  final String id;
  final ImageContentType contentType;
  final String parentId;
  final ImageVariants variants;
  final ImageMetadata metadata;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ImageAsset({
    required this.id,
    required this.contentType,
    required this.parentId,
    required this.variants,
    required this.metadata,
    this.order = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Helpers
  String get thumbnailUrl => variants.thumbnail ?? variants.original;
  String get smallUrl => variants.small ?? variants.original;
  String get mediumUrl => variants.medium ?? variants.original;
  String get largeUrl => variants.large ?? variants.original;
  String get originalUrl => variants.original;

  String getResponsiveUrl(double screenWidth) =>
      variants.getResponsiveUrl(screenWidth);

  factory ImageAsset.fromMap(Map<String, dynamic> map, String docId) {
    return ImageAsset(
      id: docId,
      contentType: ImageContentType.values.firstWhere(
        (e) => e.label == map['contentType'],
        orElse: () => ImageContentType.mediaPicture,
      ),
      parentId: map['parentId'] ?? '',
      variants: ImageVariants.fromMap(map['variants'] ?? {}),
      metadata: ImageMetadata.fromMap(map['metadata'] ?? {}),
      order: map['order'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'contentType': contentType.label,
      'parentId': parentId,
      'variants': variants.toMap(),
      'metadata': metadata.toMap(),
      'order': order,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    return map;
  }

  ImageAsset copyWith({
    String? id,
    ImageContentType? contentType,
    String? parentId,
    ImageVariants? variants,
    ImageMetadata? metadata,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ImageAsset(
      id: id ?? this.id,
      contentType: contentType ?? this.contentType,
      parentId: parentId ?? this.parentId,
      variants: variants ?? this.variants,
      metadata: metadata ?? this.metadata,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Collection d'images (pour galeries)
class ImageCollection {
  final String parentId;
  final String? coverImageId;
  final List<ImageAsset> images;

  ImageCollection({
    required this.parentId,
    this.coverImageId,
    this.images = const [],
  });

  ImageAsset? get coverImage => coverImageId != null
      ? images.firstWhere((img) => img.id == coverImageId,
          orElse: () => images.first)
      : (images.isNotEmpty ? images.first : null);

  List<ImageAsset> get galleryImages =>
      images.where((img) => img.id != coverImageId).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  int get totalImages => images.length;
  bool get hasImages => images.isNotEmpty;
  bool get hasGallery => images.length > 1;

  factory ImageCollection.fromMaps(
    String parentId,
    List<Map<String, dynamic>> imageMaps,
    String? coverImageId,
  ) {
    final images = imageMaps
        .map((map) => ImageAsset.fromMap(map, map['id'] ?? ''))
        .toList();
    return ImageCollection(
      parentId: parentId,
      coverImageId: coverImageId,
      images: images,
    );
  }
}
