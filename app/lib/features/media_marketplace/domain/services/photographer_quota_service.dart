import '../../core/enums/gallery_status.dart';
import '../../core/enums/photo_lifecycle_status.dart';
import '../../core/enums/subscription_status.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/models/photographer_plan_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/models/photographer_subscription_model.dart';

class QuotaUsage {
  final int publishedPhotoCount;
  final int activeGalleryCount;
  final int activePackCount;
  final int storageUsedBytes;

  const QuotaUsage({
    required this.publishedPhotoCount,
    required this.activeGalleryCount,
    required this.activePackCount,
    required this.storageUsedBytes,
  });
}

class QuotaState {
  final bool hasActiveSubscription;
  final bool publicationFrozen;
  final bool canPublishPhotos;
  final bool canPublishGalleries;
  final bool canActivatePacks;
  final bool storageExceeded;
  final List<String> reasons;
  final QuotaUsage usage;
  final PhotographerQuotaSnapshot? quotaSnapshot;
  final PhotographerPlanModel? plan;

  const QuotaState({
    required this.hasActiveSubscription,
    required this.publicationFrozen,
    required this.canPublishPhotos,
    required this.canPublishGalleries,
    required this.canActivatePacks,
    required this.storageExceeded,
    required this.reasons,
    required this.usage,
    this.quotaSnapshot,
    this.plan,
  });
}

class QuotaDecision {
  final bool allowed;
  final String? reason;
  final QuotaState state;

  const QuotaDecision({
    required this.allowed,
    required this.state,
    this.reason,
  });
}

class PhotographerQuotaService {
  const PhotographerQuotaService();

  QuotaDecision canPublishPhoto({
    required PhotographerProfileModel photographer,
    PhotographerPlanModel? plan,
    PhotographerSubscriptionModel? subscription,
    MediaPhotoModel? photo,
    QuotaUsage? usage,
  }) {
    final state = getQuotaState(
      photographer: photographer,
      plan: plan,
      subscription: subscription,
      usage: usage,
    );
    if (!state.canPublishPhotos) {
      return QuotaDecision(
        allowed: false,
        state: state,
        reason: state.reasons.isNotEmpty ? state.reasons.first : 'Quota photo depasse',
      );
    }
    if (photo != null && photo.lifecycleStatus != PhotoLifecycleStatus.ready) {
      return QuotaDecision(
        allowed: false,
        state: state,
        reason: 'La photo doit etre prete avant publication',
      );
    }
    return QuotaDecision(allowed: true, state: state);
  }

  QuotaDecision canPublishGallery({
    required PhotographerProfileModel photographer,
    PhotographerPlanModel? plan,
    PhotographerSubscriptionModel? subscription,
    MediaGalleryModel? gallery,
    int readyOrPublishedPhotoCount = 0,
    QuotaUsage? usage,
  }) {
    final state = getQuotaState(
      photographer: photographer,
      plan: plan,
      subscription: subscription,
      usage: usage,
    );
    if (!state.canPublishGalleries) {
      return QuotaDecision(
        allowed: false,
        state: state,
        reason: state.reasons.isNotEmpty ? state.reasons.first : 'Quota galerie depasse',
      );
    }
    if (gallery != null && gallery.status == GalleryStatus.archived) {
      return QuotaDecision(
        allowed: false,
        state: state,
        reason: 'Une galerie archivee ne peut pas etre publiee telle quelle',
      );
    }
    if (readyOrPublishedPhotoCount <= 0) {
      return QuotaDecision(
        allowed: false,
        state: state,
        reason: 'Une galerie doit contenir au moins une photo prete ou publiee',
      );
    }
    return QuotaDecision(allowed: true, state: state);
  }

  QuotaDecision canActivatePack({
    required PhotographerProfileModel photographer,
    PhotographerPlanModel? plan,
    PhotographerSubscriptionModel? subscription,
    MediaPackModel? pack,
    required bool galleryPublished,
    required bool photosValid,
    QuotaUsage? usage,
  }) {
    final state = getQuotaState(
      photographer: photographer,
      plan: plan,
      subscription: subscription,
      usage: usage,
    );
    if (!state.canActivatePacks) {
      return QuotaDecision(
        allowed: false,
        state: state,
        reason: state.reasons.isNotEmpty ? state.reasons.first : 'Quota pack depasse',
      );
    }
    if (!galleryPublished) {
      return QuotaDecision(
        allowed: false,
        state: state,
        reason: 'Le pack doit etre rattache a une galerie publiee',
      );
    }
    if (!photosValid || (pack != null && pack.photoIds.isEmpty)) {
      return QuotaDecision(
        allowed: false,
        state: state,
        reason: 'Le pack doit contenir des photos valides',
      );
    }
    return QuotaDecision(allowed: true, state: state);
  }

  QuotaUsage getQuotaUsage({
    required PhotographerProfileModel photographer,
    int? publishedPhotoCount,
    int? activeGalleryCount,
    int? activePackCount,
    int? storageUsedBytes,
  }) {
    return QuotaUsage(
      publishedPhotoCount:
          publishedPhotoCount ?? photographer.publishedPhotoCount,
      activeGalleryCount: activeGalleryCount ?? photographer.activeGalleryCount,
      activePackCount: activePackCount ?? photographer.activePackCount,
      storageUsedBytes: storageUsedBytes ?? photographer.storageUsedBytes,
    );
  }

  QuotaState getQuotaState({
    required PhotographerProfileModel photographer,
    PhotographerPlanModel? plan,
    PhotographerSubscriptionModel? subscription,
    QuotaUsage? usage,
  }) {
    final currentUsage = usage ?? getQuotaUsage(photographer: photographer);
    final snapshot = subscription?.quotaSnapshot;
    final maxPublishedPhotos =
        snapshot?.maxPublishedPhotos ?? plan?.maxPublishedPhotos ?? 0;
    final maxStorageBytes =
        snapshot?.maxStorageBytes ?? plan?.maxStorageBytes ?? 0;
    final maxActiveGalleries =
        snapshot?.maxActiveGalleries ?? plan?.maxActiveGalleries ?? 0;
    final maxActivePacks =
        snapshot?.maxActivePacks ?? plan?.maxActivePacks ?? 0;

    final hasActiveSubscription = subscription != null &&
        (subscription.status == SubscriptionStatus.active ||
            subscription.status == SubscriptionStatus.trialing ||
            subscription.status == SubscriptionStatus.pastDue);

    final storageExceeded =
        maxStorageBytes > 0 && currentUsage.storageUsedBytes > maxStorageBytes;
    final photosExceeded = maxPublishedPhotos > 0 &&
        currentUsage.publishedPhotoCount >= maxPublishedPhotos;
    final galleriesExceeded = maxActiveGalleries > 0 &&
        currentUsage.activeGalleryCount >= maxActiveGalleries;
    final packsExceeded =
        maxActivePacks > 0 && currentUsage.activePackCount >= maxActivePacks;

    final reasons = <String>[];
    if (!hasActiveSubscription) {
      reasons.add('Abonnement actif requis');
    }
    if (storageExceeded) {
      reasons.add('Quota stockage depasse');
    }
    if (photosExceeded) {
      reasons.add('Quota photos publiees atteint');
    }
    if (galleriesExceeded) {
      reasons.add('Quota galeries actives atteint');
    }
    if (packsExceeded) {
      reasons.add('Quota packs actifs atteint');
    }

    final publicationFrozen = !hasActiveSubscription || storageExceeded;

    return QuotaState(
      hasActiveSubscription: hasActiveSubscription,
      publicationFrozen: publicationFrozen,
      canPublishPhotos: !publicationFrozen && !photosExceeded,
      canPublishGalleries: !publicationFrozen && !galleriesExceeded,
      canActivatePacks: !publicationFrozen && !packsExceeded,
      storageExceeded: storageExceeded,
      reasons: reasons,
      usage: currentUsage,
      quotaSnapshot: snapshot,
      plan: plan,
    );
  }
}