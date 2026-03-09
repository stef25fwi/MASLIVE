import '../../core/enums/media_asset_type.dart';
import '../../data/models/media_entitlement_model.dart';

class DownloadState {
  final bool allowed;
  final bool hasEntitlement;
  final bool expired;
  final bool limitReached;
  final String? reason;

  const DownloadState({
    required this.allowed,
    required this.hasEntitlement,
    required this.expired,
    required this.limitReached,
    this.reason,
  });
}

class MediaAccessService {
  const MediaAccessService();

  bool canDownloadAsset({
    required MediaEntitlementModel? entitlement,
    required String assetId,
    MediaAssetType? assetType,
  }) {
    return getDownloadState(
      entitlement: entitlement,
      assetId: assetId,
      assetType: assetType,
    ).allowed;
  }

  bool canViewHdPhoto({
    required MediaEntitlementModel? entitlement,
    required String photoId,
  }) {
    if (entitlement == null || !entitlement.isActive) return false;
    if (entitlement.assetType == MediaAssetType.photo) {
      return entitlement.assetId == photoId &&
          !getDownloadState(entitlement: entitlement, assetId: photoId).expired;
    }
    return entitlement.photoIds.contains(photoId) &&
        !getDownloadState(entitlement: entitlement, assetId: entitlement.assetId).expired;
  }

  DownloadState getDownloadState({
    required MediaEntitlementModel? entitlement,
    required String assetId,
    MediaAssetType? assetType,
  }) {
    if (entitlement == null) {
      return const DownloadState(
        allowed: false,
        hasEntitlement: false,
        expired: false,
        limitReached: false,
        reason: 'Aucun entitlement actif',
      );
    }

    final expiresAt = entitlement.expiresAt;
    final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final limitReached = entitlement.downloadLimit != null &&
        entitlement.downloadCount >= entitlement.downloadLimit!;

    final assetMatches = entitlement.assetId == assetId ||
        entitlement.photoIds.contains(assetId);
    final typeMatches = assetType == null || entitlement.assetType == assetType;

    if (!entitlement.isActive) {
      return const DownloadState(
        allowed: false,
        hasEntitlement: true,
        expired: false,
        limitReached: false,
        reason: 'Entitlement inactif',
      );
    }
    if (!assetMatches || !typeMatches) {
      return const DownloadState(
        allowed: false,
        hasEntitlement: true,
        expired: false,
        limitReached: false,
        reason: 'Asset non couvert par le droit',
      );
    }
    if (expired) {
      return const DownloadState(
        allowed: false,
        hasEntitlement: true,
        expired: true,
        limitReached: false,
        reason: 'Entitlement expire',
      );
    }
    if (limitReached) {
      return const DownloadState(
        allowed: false,
        hasEntitlement: true,
        expired: false,
        limitReached: true,
        reason: 'Limite de telechargement atteinte',
      );
    }

    return const DownloadState(
      allowed: true,
      hasEntitlement: true,
      expired: false,
      limitReached: false,
    );
  }
}