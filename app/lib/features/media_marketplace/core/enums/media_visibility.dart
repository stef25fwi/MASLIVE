enum MediaVisibility {
  public,
  private,
  unlisted;

  String get firestoreValue => name;

  String get label {
    switch (this) {
      case MediaVisibility.public:
        return 'Public';
      case MediaVisibility.private:
        return 'Privé';
      case MediaVisibility.unlisted:
        return 'Non listé';
    }
  }
}

MediaVisibility mediaVisibilityFromString(
  String? value, {
  MediaVisibility fallback = MediaVisibility.private,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'public':
      return MediaVisibility.public;
    case 'private':
      return MediaVisibility.private;
    case 'unlisted':
      return MediaVisibility.unlisted;
    default:
      return fallback;
  }
}
