import '../../data/models/photographer_plan_model.dart';

const int _gib = 1024 * 1024 * 1024;
const int _mib = 1024 * 1024;

class PhotoPackTier {
  const PhotoPackTier({
    required this.code,
    required this.title,
    required this.photoCount,
    required this.price,
    this.highlighted = false,
    this.description,
  });

  final String code;
  final String title;
  final int photoCount;
  final double price;
  final bool highlighted;
  final String? description;

  double get unitPrice => price / photoCount;
}

class PhotographerPlanSpec {
  const PhotographerPlanSpec({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.maxPublishedPhotos,
    required this.maxStorageBytes,
    required this.maxActiveGalleries,
    required this.maxActivePacks,
    required this.maxFileBytes,
    required this.maxMegapixels,
    required this.retentionDays,
    required this.commissionRate,
    required this.qualityLabel,
    required this.features,
    this.maxCollaborators = 1,
    this.customWatermark = false,
    this.prioritySupport = false,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final double monthlyPrice;
  final double annualPrice;
  final int maxPublishedPhotos;
  final int maxStorageBytes;
  final int maxActiveGalleries;
  final int maxActivePacks;
  final int maxFileBytes;
  final int maxMegapixels;
  final int retentionDays;
  final double commissionRate;
  final String qualityLabel;
  final List<String> features;
  final int maxCollaborators;
  final bool customWatermark;
  final bool prioritySupport;

  double storageRatio(int usedBytes) => maxStorageBytes <= 0
      ? 0
      : (usedBytes / maxStorageBytes).clamp(0, 1.5).toDouble();

  double photoRatio(int usedPhotos) => maxPublishedPhotos <= 0
      ? 0
      : (usedPhotos / maxPublishedPhotos).clamp(0, 1.5).toDouble();

  PhotographerPlanModel toModel({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return PhotographerPlanModel(
      planId: id,
      code: code,
      name: name,
      description: description,
      monthlyPrice: monthlyPrice,
      annualPrice: annualPrice,
      maxPublishedPhotos: maxPublishedPhotos,
      maxStorageBytes: maxStorageBytes,
      maxActiveGalleries: maxActiveGalleries,
      maxActivePacks: maxActivePacks,
      commissionRate: commissionRate,
      features: <String>[
        ...features,
        'Qualité: $qualityLabel',
        'Fichier max: ${(maxFileBytes / _mib).round()} Mo',
        'Définition max: $maxMegapixels MP',
        'Conservation active: $retentionDays jours',
        'Commission MASLIVE: ${(commissionRate * 100).round()} %',
      ],
      isActive: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}

class StorageExtensionSpec {
  const StorageExtensionSpec({
    required this.code,
    required this.title,
    required this.monthlyPrice,
    required this.extraPhotos,
    required this.extraStorageBytes,
    this.durationDays,
  });

  final String code;
  final String title;
  final double monthlyPrice;
  final int extraPhotos;
  final int extraStorageBytes;
  final int? durationDays;
}

class MediaMarketplacePricing {
  const MediaMarketplacePricing._();

  static const List<PhotoPackTier> buyerPacks = <PhotoPackTier>[
    PhotoPackTier(
      code: 'single',
      title: '1 photo souvenir',
      photoCount: 1,
      price: 6.90,
      description: 'La photo coup de cœur en haute qualité numérique.',
    ),
    PhotoPackTier(
      code: 'duo',
      title: 'Pack Duo',
      photoCount: 2,
      price: 10.90,
      description: 'Portrait + action, soit 5,45 € par photo.',
    ),
    PhotoPackTier(
      code: 'essential',
      title: 'Pack Essentiel',
      photoCount: 5,
      price: 19.90,
      highlighted: true,
      description: 'L’offre recommandée, soit 3,98 € par photo.',
    ),
    PhotoPackTier(
      code: 'experience',
      title: 'Pack Expérience',
      photoCount: 10,
      price: 29.90,
      description: 'Le parcours en images, soit 2,99 € par photo.',
    ),
    PhotoPackTier(
      code: 'personal_gallery',
      title: 'Galerie personnelle',
      photoCount: 20,
      price: 44.90,
      description: 'Toute votre expérience, soit 2,25 € par photo.',
    ),
  ];

  static const List<PhotographerPlanSpec> photographerPlans =
      <PhotographerPlanSpec>[
    PhotographerPlanSpec(
      id: 'discovery',
      code: 'discovery',
      name: 'Découverte',
      description: 'Pour tester la vente sur un ou deux circuits sans engagement.',
      monthlyPrice: 0,
      annualPrice: 0,
      maxPublishedPhotos: 250,
      maxStorageBytes: 3 * _gib,
      maxActiveGalleries: 2,
      maxActivePacks: 10,
      maxFileBytes: 8 * _mib,
      maxMegapixels: 12,
      retentionDays: 30,
      commissionRate: 0.30,
      qualityLabel: 'JPEG 12 MP',
      features: <String>[
        '2 galeries actives',
        'Miniatures et aperçus filigranés',
        'Expiration automatique après 30 jours',
      ],
    ),
    PhotographerPlanSpec(
      id: 'pro',
      code: 'pro',
      name: 'Pro',
      description: 'L’offre recommandée pour les photographes indépendants.',
      monthlyPrice: 19.90,
      annualPrice: 199,
      maxPublishedPhotos: 3000,
      maxStorageBytes: 30 * _gib,
      maxActiveGalleries: 20,
      maxActivePacks: 100,
      maxFileBytes: 20 * _mib,
      maxMegapixels: 24,
      retentionDays: 183,
      commissionRate: 0.25,
      qualityLabel: 'JPEG 24 MP',
      features: <String>[
        '20 galeries actives',
        'Statistiques par galerie',
        'Codes promotionnels',
        'Personnalisation légère de la boutique',
      ],
    ),
    PhotographerPlanSpec(
      id: 'studio',
      code: 'studio',
      name: 'Studio',
      description: 'Pour les studios événementiels et les volumes réguliers.',
      monthlyPrice: 39.90,
      annualPrice: 399,
      maxPublishedPhotos: 10000,
      maxStorageBytes: 120 * _gib,
      maxActiveGalleries: 999,
      maxActivePacks: 500,
      maxFileBytes: 40 * _mib,
      maxMegapixels: 40,
      retentionDays: 365,
      commissionRate: 0.20,
      qualityLabel: 'JPEG 40 MP',
      maxCollaborators: 5,
      customWatermark: true,
      features: <String>[
        'Galeries illimitées dans la limite du quota',
        'Import par dossiers',
        '5 collaborateurs',
        'Logo et filigrane personnalisés',
        'Exports ventes et clients',
      ],
    ),
    PhotographerPlanSpec(
      id: 'agency',
      code: 'agency',
      name: 'Agence',
      description: 'Pour les équipes, marques et organisateurs multi-événements.',
      monthlyPrice: 79.90,
      annualPrice: 799,
      maxPublishedPhotos: 30000,
      maxStorageBytes: 400 * _gib,
      maxActiveGalleries: 9999,
      maxActivePacks: 2000,
      maxFileBytes: 60 * _mib,
      maxMegapixels: 60,
      retentionDays: 548,
      commissionRate: 0.15,
      qualityLabel: 'JPEG HD 60 MP',
      maxCollaborators: 25,
      customWatermark: true,
      prioritySupport: true,
      features: <String>[
        '25 photographes ou collaborateurs',
        'Plusieurs boutiques et marques',
        'Import automatisé et API',
        'Priorisation des galeries',
        'Support prioritaire',
      ],
    ),
  ];

  static const List<StorageExtensionSpec> storageExtensions =
      <StorageExtensionSpec>[
    StorageExtensionSpec(
      code: 'plus_1000',
      title: '+1 000 photos et +10 Go',
      monthlyPrice: 5.90,
      extraPhotos: 1000,
      extraStorageBytes: 10 * _gib,
    ),
    StorageExtensionSpec(
      code: 'plus_5000',
      title: '+5 000 photos et +50 Go',
      monthlyPrice: 19.90,
      extraPhotos: 5000,
      extraStorageBytes: 50 * _gib,
    ),
    StorageExtensionSpec(
      code: 'event_30d',
      title: 'Stockage événementiel 30 jours',
      monthlyPrice: 9.90,
      extraPhotos: 5000,
      extraStorageBytes: 50 * _gib,
      durationDays: 30,
    ),
  ];

  static PhotographerPlanSpec planFor(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return photographerPlans.firstWhere(
      (plan) => plan.id == normalized || plan.code == normalized,
      orElse: () => photographerPlans.first,
    );
  }

  static PhotoPackTier? exactPack(int photoCount) {
    for (final tier in buyerPacks) {
      if (tier.photoCount == photoCount) return tier;
    }
    return null;
  }

  static List<PhotoPackTier> bestPackCombination(int photoCount) {
    if (photoCount <= 0) return const <PhotoPackTier>[];
    final sorted = [...buyerPacks]
      ..sort((a, b) => b.photoCount.compareTo(a.photoCount));
    var remaining = photoCount;
    final result = <PhotoPackTier>[];
    for (final tier in sorted) {
      while (remaining >= tier.photoCount) {
        result.add(tier);
        remaining -= tier.photoCount;
      }
    }
    return result;
  }

  static double priceForPhotoCount(int photoCount) => bestPackCombination(
        photoCount,
      ).fold<double>(0, (total, tier) => total + tier.price);
}
