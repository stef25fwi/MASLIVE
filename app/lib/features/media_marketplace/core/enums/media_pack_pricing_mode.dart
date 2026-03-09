enum MediaPackPricingMode {
  fixedPack,
  pickN,
  fullGallery,
}

MediaPackPricingMode mediaPackPricingModeFromString(
  String? value, {
  MediaPackPricingMode fallback = MediaPackPricingMode.fixedPack,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'fixed_pack':
    case 'fixedpack':
      return MediaPackPricingMode.fixedPack;
    case 'pick_n':
    case 'pickn':
      return MediaPackPricingMode.pickN;
    case 'full_gallery':
    case 'fullgallery':
      return MediaPackPricingMode.fullGallery;
    default:
      return fallback;
  }
}

extension MediaPackPricingModeX on MediaPackPricingMode {
  String get firestoreValue {
    switch (this) {
      case MediaPackPricingMode.fixedPack:
        return 'fixed_pack';
      case MediaPackPricingMode.pickN:
        return 'pick_n';
      case MediaPackPricingMode.fullGallery:
        return 'full_gallery';
    }
  }

  String get label {
    switch (this) {
      case MediaPackPricingMode.fixedPack:
        return 'Pack fixe';
      case MediaPackPricingMode.pickN:
        return 'Choix N photos';
      case MediaPackPricingMode.fullGallery:
        return 'Galerie complete';
    }
  }
}