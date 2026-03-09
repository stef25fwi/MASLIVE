enum PhotoLifecycleStatus {
  draft,
  processing,
  ready,
  published,
  archived,
}

PhotoLifecycleStatus photoLifecycleStatusFromString(
  String? value, {
  PhotoLifecycleStatus fallback = PhotoLifecycleStatus.draft,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'draft':
      return PhotoLifecycleStatus.draft;
    case 'processing':
      return PhotoLifecycleStatus.processing;
    case 'ready':
      return PhotoLifecycleStatus.ready;
    case 'published':
      return PhotoLifecycleStatus.published;
    case 'archived':
      return PhotoLifecycleStatus.archived;
    default:
      return fallback;
  }
}

extension PhotoLifecycleStatusX on PhotoLifecycleStatus {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case PhotoLifecycleStatus.draft:
        return 'Brouillon';
      case PhotoLifecycleStatus.processing:
        return 'Traitement';
      case PhotoLifecycleStatus.ready:
        return 'Pret';
      case PhotoLifecycleStatus.published:
        return 'Publie';
      case PhotoLifecycleStatus.archived:
        return 'Archive';
    }
  }
}