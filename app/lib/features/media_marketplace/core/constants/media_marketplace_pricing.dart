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

class PhotoPackQuote {
  const PhotoPackQuote({
    required this.requestedPhotoCount,
    required this.billedPhotoCount,
    required this.packs,
    required this.total,
  });

  final int requestedPhotoCount;
  final int billedPhotoCount;
  final List<PhotoPackTier> packs;
  final double total;

  int get bonusPhotoSlots => billedPhotoCount - requestedPhotoCount;
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
    this.includedBasicAiCredits = 0,
    this.includedAdvancedAiCredits = 0,
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
  final int includedBasicAiCredits;
  final int includedAdvancedAiCredits;

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
        'Analyses IA: crédits séparés, débit uniquement lors de l’analyse',
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
    required this.kind,
    required this.title,
    required this.description,
    required this.monthlyPrice,
    required this.extraPhotos,
    required this.extraStorageBytes,
    this.basicAiCredits = 0,
    this.advancedAiCredits = 0,
    this.durationDays,
    this.creditsNeverExpire = false,
    this.creditsExpireWithExtension = false,
  });

  final String code;
  final String kind;
  final String title;
  final String description;
  final double monthlyPrice;
  final int extraPhotos;
  final int extraStorageBytes;
  final int basicAiCredits;
  final int advancedAiCredits;
  final int? durationDays;
  final bool creditsNeverExpire;
  final bool creditsExpireWithExtension;

  bool get recurring => durationDays == null;
  bool get hasStorage => extraPhotos > 0 || extraStorageBytes > 0;
  bool get hasAiCredits => basicAiCredits > 0 || advancedAiCredits > 0;
  bool get isEventPack => kind.startsWith('event_');

  String get billingLabel {
    if (recurring) return '${monthlyPrice.toStringAsFixed(2)} € / mois';
    if (creditsNeverExpire) {
      return '${monthlyPrice.toStringAsFixed(2)} € • achat unique';
    }
    return '${monthlyPrice.toStringAsFixed(2)} € pour ${durationDays ?? 30} jours';
  }

  List<String> get capacityLines {
    final values = <String>[];
    if (hasStorage) {
      values.add(
        '+$extraPhotos photos • '
        '+${(extraStorageBytes / _gib).round()} Go',
      );
    }
    if (basicAiCredits > 0) {
      values.add('$basicAiCredits crédits OCR, couleurs et tags');
    }
    if (advancedAiCredits > 0) {
      values.add('$advancedAiCredits crédits avancés avec regroupement visuel');
    }
    if (creditsNeverExpire && hasAiCredits) {
      values.add('Crédits sans expiration');
    } else if (creditsExpireWithExtension && hasAiCredits) {
      values.add('Crédits utilisables pendant la durée de l’événement');
    }
    return values;
  }
}

class MediaMarketplacePricing {
  const MediaMarketplacePricing._();

  static const double estimatedAiCostPerAnalysisEur = 0.01;

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
      kind: 'storage',
      title: '+1 000 photos et +10 Go',
      description: 'Extension récurrente de capacité active.',
      monthlyPrice: 5.90,
      extraPhotos: 1000,
      extraStorageBytes: 10 * _gib,
    ),
    StorageExtensionSpec(
      code: 'plus_5000',
      kind: 'storage',
      title: '+5 000 photos et +50 Go',
      description: 'Extension récurrente pour les volumes réguliers.',
      monthlyPrice: 19.90,
      extraPhotos: 5000,
      extraStorageBytes: 50 * _gib,
    ),
    StorageExtensionSpec(
      code: 'ai_basic_1000',
      kind: 'ai_basic',
      title: '1 000 analyses OCR et couleurs',
      description: 'Dossards, couleurs dominantes et tags automatiques.',
      monthlyPrice: 7.90,
      extraPhotos: 0,
      extraStorageBytes: 0,
      basicAiCredits: 1000,
      durationDays: 36500,
      creditsNeverExpire: true,
    ),
    StorageExtensionSpec(
      code: 'ai_advanced_1000',
      kind: 'ai_advanced',
      title: '1 000 analyses avancées avec regroupement visuel',
      description:
          'OCR, couleurs, tags et regroupement visuel anonyme avec consentement.',
      monthlyPrice: 11.90,
      extraPhotos: 0,
      extraStorageBytes: 0,
      advancedAiCredits: 1000,
      durationDays: 36500,
      creditsNeverExpire: true,
    ),
    StorageExtensionSpec(
      code: 'event_30d',
      kind: 'event_storage',
      title: 'Événement 30 jours sans analyse IA',
      description: '+5 000 photos et +50 Go pendant 30 jours.',
      monthlyPrice: 14.90,
      extraPhotos: 5000,
      extraStorageBytes: 50 * _gib,
      durationDays: 30,
    ),
    StorageExtensionSpec(
      code: 'event_30d_basic',
      kind: 'event_basic',
      title: 'Événement 30 jours avec 5 000 analyses basiques',
      description: '+5 000 photos, +50 Go et 5 000 analyses OCR/couleurs.',
      monthlyPrice: 29.90,
      extraPhotos: 5000,
      extraStorageBytes: 50 * _gib,
      basicAiCredits: 5000,
      durationDays: 30,
      creditsExpireWithExtension: true,
    ),
    StorageExtensionSpec(
      code: 'event_30d_advanced',
      kind: 'event_advanced',
      title: 'Événement 30 jours avec analyse avancée',
      description: '+5 000 photos, +50 Go et 5 000 analyses avancées.',
      monthlyPrice: 39.90,
      extraPhotos: 5000,
      extraStorageBytes: 50 * _gib,
      advancedAiCredits: 5000,
      durationDays: 30,
      creditsExpireWithExtension: true,
    ),
  ];

  static PhotographerPlanSpec planFor(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return photographerPlans.firstWhere(
      (plan) => plan.id == normalized || plan.code == normalized,
      orElse: () => photographerPlans.first,
    );
  }

  static StorageExtensionSpec? extensionFor(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final extension in storageExtensions) {
      if (extension.code == normalized) return extension;
    }
    return null;
  }

  static PhotoPackTier? exactPack(int photoCount) {
    for (final tier in buyerPacks) {
      if (tier.photoCount == photoCount) return tier;
    }
    return null;
  }

  static PhotoPackQuote quoteForPhotoCount(int photoCount) {
    if (photoCount <= 0) {
      return const PhotoPackQuote(
        requestedPhotoCount: 0,
        billedPhotoCount: 0,
        packs: <PhotoPackTier>[],
        total: 0,
      );
    }

    final maxPackSize = buyerPacks
        .map((tier) => tier.photoCount)
        .reduce((a, b) => a > b ? a : b);
    final maxBilledCount = photoCount + maxPackSize - 1;
    final bestPrices = List<double>.filled(maxBilledCount + 1, double.infinity);
    final bestCombinations = List<List<PhotoPackTier>?>.filled(
      maxBilledCount + 1,
      null,
    );
    bestPrices[0] = 0;
    bestCombinations[0] = const <PhotoPackTier>[];

    for (var count = 1; count <= maxBilledCount; count++) {
      for (final tier in buyerPacks) {
        final previous = count - tier.photoCount;
        if (previous < 0 || bestCombinations[previous] == null) continue;
        final candidate = bestPrices[previous] + tier.price;
        if (candidate < bestPrices[count] - 0.0001) {
          bestPrices[count] = candidate;
          bestCombinations[count] = <PhotoPackTier>[
            ...bestCombinations[previous]!,
            tier,
          ];
        }
      }
    }

    var chosenCount = photoCount;
    for (var count = photoCount; count <= maxBilledCount; count++) {
      final candidate = bestCombinations[count];
      if (candidate == null) continue;
      if (bestCombinations[chosenCount] == null ||
          bestPrices[count] < bestPrices[chosenCount] - 0.0001 ||
          ((bestPrices[count] - bestPrices[chosenCount]).abs() < 0.0001 &&
              count < chosenCount)) {
        chosenCount = count;
      }
    }

    return PhotoPackQuote(
      requestedPhotoCount: photoCount,
      billedPhotoCount: chosenCount,
      packs: List<PhotoPackTier>.unmodifiable(bestCombinations[chosenCount]!),
      total: double.parse(bestPrices[chosenCount].toStringAsFixed(2)),
    );
  }

  static List<PhotoPackTier> bestPackCombination(int photoCount) =>
      quoteForPhotoCount(photoCount).packs;

  static double priceForPhotoCount(int photoCount) =>
      quoteForPhotoCount(photoCount).total;
}
