/// Helpers de génération des chemins Firebase Storage du module media marketplace.
class MediaMarketplaceStoragePaths {
  const MediaMarketplaceStoragePaths._();

  static String galleryRoot({
    required String photographerId,
    required String eventId,
    required String galleryId,
  }) {
    return 'photographers/$photographerId/events/$eventId/galleries/$galleryId';
  }

  static String originalsDir({
    required String photographerId,
    required String eventId,
    required String galleryId,
  }) {
    return '${galleryRoot(photographerId: photographerId, eventId: eventId, galleryId: galleryId)}/originals';
  }

  static String previewsDir({
    required String photographerId,
    required String eventId,
    required String galleryId,
  }) {
    return '${galleryRoot(photographerId: photographerId, eventId: eventId, galleryId: galleryId)}/previews';
  }

  static String thumbsDir({
    required String photographerId,
    required String eventId,
    required String galleryId,
  }) {
    return '${galleryRoot(photographerId: photographerId, eventId: eventId, galleryId: galleryId)}/thumbs';
  }

  static String watermarkedDir({
    required String photographerId,
    required String eventId,
    required String galleryId,
  }) {
    return '${galleryRoot(photographerId: photographerId, eventId: eventId, galleryId: galleryId)}/watermarked';
  }

  static String originalPath({
    required String photographerId,
    required String eventId,
    required String galleryId,
    required String photoId,
    String extension = 'jpg',
  }) {
    return '${originalsDir(photographerId: photographerId, eventId: eventId, galleryId: galleryId)}/$photoId.$extension';
  }

  static String previewPath({
    required String photographerId,
    required String eventId,
    required String galleryId,
    required String photoId,
    String extension = 'jpg',
  }) {
    return '${previewsDir(photographerId: photographerId, eventId: eventId, galleryId: galleryId)}/$photoId.$extension';
  }

  static String thumbnailPath({
    required String photographerId,
    required String eventId,
    required String galleryId,
    required String photoId,
    String extension = 'jpg',
  }) {
    return '${thumbsDir(photographerId: photographerId, eventId: eventId, galleryId: galleryId)}/$photoId.$extension';
  }

  static String watermarkedPath({
    required String photographerId,
    required String eventId,
    required String galleryId,
    required String photoId,
    String extension = 'jpg',
  }) {
    return '${watermarkedDir(photographerId: photographerId, eventId: eventId, galleryId: galleryId)}/$photoId.$extension';
  }
}