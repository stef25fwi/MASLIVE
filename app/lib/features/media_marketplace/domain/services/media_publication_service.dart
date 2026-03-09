import '../../core/enums/gallery_status.dart';
import '../../core/enums/moderation_status.dart';
import '../../core/enums/photo_lifecycle_status.dart';
import '../../core/enums/photographer_status.dart';
import '../../core/enums/subscription_status.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/models/photographer_subscription_model.dart';
import 'photographer_quota_service.dart';

class PublicationDecision {
  final bool allowed;
  final String? reason;

  const PublicationDecision({required this.allowed, this.reason});
}

class MediaPublicationService {
  const MediaPublicationService({PhotographerQuotaService? quotaService})
    : _quotaService = quotaService ?? const PhotographerQuotaService();

  final PhotographerQuotaService _quotaService;

  PublicationDecision canPublishPhoto({
    required PhotographerProfileModel photographer,
    required MediaPhotoModel photo,
    required PhotographerSubscriptionModel? subscription,
    QuotaUsage? usage,
  }) {
    if (photographer.status != PhotographerStatus.approved) {
      return const PublicationDecision(
        allowed: false,
        reason: 'Photographe non approuve',
      );
    }
    if (subscription == null ||
        (subscription.status != SubscriptionStatus.active &&
            subscription.status != SubscriptionStatus.trialing &&
            subscription.status != SubscriptionStatus.pastDue)) {
      return const PublicationDecision(
        allowed: false,
        reason: 'Abonnement actif requis',
      );
    }
    if (photo.lifecycleStatus != PhotoLifecycleStatus.ready) {
      return const PublicationDecision(
        allowed: false,
        reason: 'La photo doit etre ready avant publication',
      );
    }
    if (photo.moderationStatus == ModerationStatus.rejected) {
      return const PublicationDecision(
        allowed: false,
        reason: 'Photo rejetee par moderation',
      );
    }
    final decision = _quotaService.canPublishPhoto(
      photographer: photographer,
      subscription: subscription,
      photo: photo,
      usage: usage,
    );
    return PublicationDecision(allowed: decision.allowed, reason: decision.reason);
  }

  PublicationDecision canPublishGallery({
    required PhotographerProfileModel photographer,
    required MediaGalleryModel gallery,
    required PhotographerSubscriptionModel? subscription,
    required int readyOrPublishedPhotoCount,
    QuotaUsage? usage,
  }) {
    if (photographer.status != PhotographerStatus.approved) {
      return const PublicationDecision(
        allowed: false,
        reason: 'Photographe non approuve',
      );
    }
    if (subscription == null ||
        (subscription.status != SubscriptionStatus.active &&
            subscription.status != SubscriptionStatus.trialing &&
            subscription.status != SubscriptionStatus.pastDue)) {
      return const PublicationDecision(
        allowed: false,
        reason: 'Abonnement actif requis',
      );
    }
    if (gallery.status == GalleryStatus.archived) {
      return const PublicationDecision(
        allowed: false,
        reason: 'Galerie archivee',
      );
    }
    final decision = _quotaService.canPublishGallery(
      photographer: photographer,
      subscription: subscription,
      gallery: gallery,
      readyOrPublishedPhotoCount: readyOrPublishedPhotoCount,
      usage: usage,
    );
    return PublicationDecision(allowed: decision.allowed, reason: decision.reason);
  }

  PublicationDecision canActivatePack({
    required PhotographerProfileModel photographer,
    required MediaPackModel pack,
    required MediaGalleryModel? gallery,
    required PhotographerSubscriptionModel? subscription,
    required bool photosValid,
    QuotaUsage? usage,
  }) {
    if (photographer.status != PhotographerStatus.approved) {
      return const PublicationDecision(
        allowed: false,
        reason: 'Photographe non approuve',
      );
    }
    if (subscription == null ||
        (subscription.status != SubscriptionStatus.active &&
            subscription.status != SubscriptionStatus.trialing &&
            subscription.status != SubscriptionStatus.pastDue)) {
      return const PublicationDecision(
        allowed: false,
        reason: 'Abonnement actif requis',
      );
    }
    final decision = _quotaService.canActivatePack(
      photographer: photographer,
      subscription: subscription,
      pack: pack,
      galleryPublished: gallery?.status == GalleryStatus.published,
      photosValid: photosValid,
      usage: usage,
    );
    return PublicationDecision(allowed: decision.allowed, reason: decision.reason);
  }
}