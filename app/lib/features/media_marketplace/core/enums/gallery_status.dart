enum GalleryStatus {
  draft,
  processing,
  published,
  archived,
}

GalleryStatus galleryStatusFromString(
  String? value, {
  GalleryStatus fallback = GalleryStatus.draft,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'draft':
      return GalleryStatus.draft;
    case 'processing':
      return GalleryStatus.processing;
    case 'published':
      return GalleryStatus.published;
    case 'archived':
      return GalleryStatus.archived;
    default:
      return fallback;
  }
}

extension GalleryStatusX on GalleryStatus {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case GalleryStatus.draft:
        return 'Brouillon';
      case GalleryStatus.processing:
        return 'Traitement';
      case GalleryStatus.published:
        return 'Publie';
      case GalleryStatus.archived:
        return 'Archive';
    }
  }
}