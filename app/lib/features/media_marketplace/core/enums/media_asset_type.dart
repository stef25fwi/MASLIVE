enum MediaAssetType {
  photo,
  pack,
}

MediaAssetType mediaAssetTypeFromString(
  String? value, {
  MediaAssetType fallback = MediaAssetType.photo,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'photo':
      return MediaAssetType.photo;
    case 'pack':
      return MediaAssetType.pack;
    default:
      return fallback;
  }
}

extension MediaAssetTypeX on MediaAssetType {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case MediaAssetType.photo:
        return 'Photo';
      case MediaAssetType.pack:
        return 'Pack';
    }
  }
}