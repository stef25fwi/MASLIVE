class PhotographerPlanDefinition {
  const PhotographerPlanDefinition({
    required this.code,
    required this.name,
    required this.monthlyPrice,
    required this.maxPublishedPhotos,
    required this.maxStorageBytes,
    required this.maxActiveGalleries,
    required this.maxFileBytes,
    required this.maxMegapixels,
    required this.retentionDays,
    required this.commissionRate,
    required this.maxBatchUpload,
    required this.features,
  });

  final String code;
  final String name;
  final double monthlyPrice;
  final int maxPublishedPhotos;
  final int maxStorageBytes;
  final int maxActiveGalleries;
  final int maxFileBytes;
  final int maxMegapixels;
  final int retentionDays;
  final double commissionRate;
  final int maxBatchUpload;
  final List<String> features;

  double get storageGigabytes => maxStorageBytes / (1024 * 1024 * 1024);
  int get commissionPercent => (commissionRate * 100).round();
}

class BuyerPhotoPackDefinition {
  const BuyerPhotoPackDefinition({
    required this.code,
    required this.title,
    required this.pickCount,
    required this.price,
    required this.oldPrice,
    required this.description,
    this.recommended = false,
  });

  final String code;
  final String title;
  final int pickCount;
  final double price;
  final double oldPrice;
  final String description;
  final bool recommended;

  double get unitPrice => price / pickCount;
}

abstract final class PhotographerCommercialCatalog {
  static const int gibibyte = 1024 * 1024 * 1024;

  static const PhotographerPlanDefinition discovery = PhotographerPlanDefinition(
    code: 'discovery',
    name: 'Découverte',
    monthlyPrice: 0,
    maxPublishedPhotos: 250,
    maxStorageBytes: 3 * gibibyte,
    maxActiveGalleries: 2,
    maxFileBytes: 8 * 1024 * 1024,
    maxMegapixels: 12,
    retentionDays: 30,
    commissionRate: 0.30,
    maxBatchUpload: 25,
    features: <String>[
      '2 galeries actives',
      'JPEG jusqu’à 12 Mpx',
      'Prévisualisations filigranées',
      'Conservation 30 jours',
    ],
  );

  static const PhotographerPlanDefinition pro = PhotographerPlanDefinition(
    code: 'pro',
    name: 'Pro',
    monthlyPrice: 19.90,
    maxPublishedPhotos: 3000,
    maxStorageBytes: 30 * gibibyte,
    maxActiveGalleries: 20,
    maxFileBytes: 20 * 1024 * 1024,
    maxMegapixels: 24,
    retentionDays: 180,
    commissionRate: 0.25,
    maxBatchUpload: 100,
    features: <String>[
      '20 galeries actives',
      'JPEG jusqu’à 24 Mpx',
      'Statistiques par galerie',
      'Codes promotionnels',
    ],
  );

  static const PhotographerPlanDefinition studio = PhotographerPlanDefinition(
    code: 'studio',
    name: 'Studio',
    monthlyPrice: 39.90,
    maxPublishedPhotos: 10000,
    maxStorageBytes: 120 * gibibyte,
    maxActiveGalleries: 100,
    maxFileBytes: 40 * 1024 * 1024,
    maxMegapixels: 40,
    retentionDays: 365,
    commissionRate: 0.20,
    maxBatchUpload: 250,
    features: <String>[
      'Galeries illimitées dans le quota',
      'JPEG jusqu’à 40 Mpx',
      'Collaborateurs',
      'Filigrane personnalisé',
    ],
  );

  static const PhotographerPlanDefinition agency = PhotographerPlanDefinition(
    code: 'agency',
    name: 'Agence',
    monthlyPrice: 79.90,
    maxPublishedPhotos: 30000,
    maxStorageBytes: 400 * gibibyte,
    maxActiveGalleries: 500,
    maxFileBytes: 70 * 1024 * 1024,
    maxMegapixels: 60,
    retentionDays: 548,
    commissionRate: 0.15,
    maxBatchUpload: 500,
    features: <String>[
      'Plusieurs photographes',
      'Plusieurs boutiques',
      'Import automatisé',
      'Support prioritaire',
    ],
  );

  static const List<PhotographerPlanDefinition> plans = <PhotographerPlanDefinition>[
    discovery,
    pro,
    studio,
    agency,
  ];

  static const List<BuyerPhotoPackDefinition> buyerPacks = <BuyerPhotoPackDefinition>[
    BuyerPhotoPackDefinition(
      code: 'single',
      title: '1 photo souvenir',
      pickCount: 1,
      price: 6.90,
      oldPrice: 6.90,
      description: 'La photo que vous préférez.',
    ),
    BuyerPhotoPackDefinition(
      code: 'duo',
      title: 'Pack Duo',
      pickCount: 2,
      price: 10.90,
      oldPrice: 13.80,
      description: 'Un portrait et une photo en action.',
    ),
    BuyerPhotoPackDefinition(
      code: 'essential',
      title: 'Pack Essentiel',
      pickCount: 5,
      price: 19.90,
      oldPrice: 34.50,
      description: 'Le meilleur équilibre pour revivre votre parcours.',
      recommended: true,
    ),
    BuyerPhotoPackDefinition(
      code: 'experience',
      title: 'Pack Expérience',
      pickCount: 10,
      price: 29.90,
      oldPrice: 69.00,
      description: 'Pour votre groupe, votre famille ou tout le parcours.',
    ),
    BuyerPhotoPackDefinition(
      code: 'personal_gallery',
      title: 'Galerie personnelle',
      pickCount: 20,
      price: 44.90,
      oldPrice: 138.00,
      description: 'Une sélection complète à télécharger.',
    ),
  ];

  static PhotographerPlanDefinition resolve(String? rawCode) {
    final normalized = (rawCode ?? '').trim().toLowerCase();
    if (normalized.contains('agency') || normalized.contains('agence')) {
      return agency;
    }
    if (normalized.contains('studio')) return studio;
    if (normalized.contains('pro')) return pro;
    return discovery;
  }
}
