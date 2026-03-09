import 'package:flutter/foundation.dart';

import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_order_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/models/photographer_subscription_model.dart';
import '../../data/repositories/media_gallery_repository.dart';
import '../../data/repositories/media_order_repository.dart';
import '../../data/repositories/media_pack_repository.dart';
import '../../data/repositories/media_photo_repository.dart';
import '../../data/repositories/photographer_repository.dart';
import '../../data/repositories/photographer_subscription_repository.dart';

class PhotographerDashboardController extends ChangeNotifier {
  PhotographerDashboardController({
    PhotographerRepository? photographerRepository,
    PhotographerSubscriptionRepository? photographerSubscriptionRepository,
    MediaGalleryRepository? mediaGalleryRepository,
    MediaPhotoRepository? mediaPhotoRepository,
    MediaPackRepository? mediaPackRepository,
    MediaOrderRepository? mediaOrderRepository,
  }) : _photographerRepository =
           photographerRepository ?? PhotographerRepository(),
       _photographerSubscriptionRepository =
           photographerSubscriptionRepository ?? PhotographerSubscriptionRepository(),
       _mediaGalleryRepository = mediaGalleryRepository ?? MediaGalleryRepository(),
       _mediaPhotoRepository = mediaPhotoRepository ?? MediaPhotoRepository(),
       _mediaPackRepository = mediaPackRepository ?? MediaPackRepository(),
       _mediaOrderRepository = mediaOrderRepository ?? MediaOrderRepository();

  final PhotographerRepository _photographerRepository;
  final PhotographerSubscriptionRepository _photographerSubscriptionRepository;
  final MediaGalleryRepository _mediaGalleryRepository;
  final MediaPhotoRepository _mediaPhotoRepository;
  final MediaPackRepository _mediaPackRepository;
  final MediaOrderRepository _mediaOrderRepository;

  bool loading = false;
  Object? error;
  String? ownerUid;
  PhotographerProfileModel? profile;
  PhotographerSubscriptionModel? activeSubscription;
  List<MediaGalleryModel> galleries = const <MediaGalleryModel>[];
  List<MediaOrderModel> recentOrders = const <MediaOrderModel>[];
  String? selectedGalleryId;
  List<MediaPhotoModel> selectedGalleryPhotos = const <MediaPhotoModel>[];
  List<MediaPackModel> selectedGalleryPacks = const <MediaPackModel>[];

  Future<void> loadForOwnerUid(String nextOwnerUid) async {
    loading = true;
    error = null;
    ownerUid = nextOwnerUid;
    notifyListeners();

    try {
      final photographer = await _photographerRepository.getByOwnerUid(nextOwnerUid);
      profile = photographer;

      if (photographer == null) {
        activeSubscription = null;
        galleries = const <MediaGalleryModel>[];
        recentOrders = const <MediaOrderModel>[];
        selectedGalleryId = null;
        selectedGalleryPhotos = const <MediaPhotoModel>[];
        selectedGalleryPacks = const <MediaPackModel>[];
        return;
      }

      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _photographerSubscriptionRepository.getActiveByPhotographerId(
          photographer.photographerId,
        ),
        _mediaGalleryRepository.getByPhotographer(photographer.photographerId),
        _mediaOrderRepository.getByPhotographer(photographer.photographerId),
      ]);

      activeSubscription = results[0] as PhotographerSubscriptionModel?;
      galleries = results[1] as List<MediaGalleryModel>;
      recentOrders = results[2] as List<MediaOrderModel>;
    } catch (err) {
      error = err;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectGallery(String galleryId) async {
    loading = true;
    error = null;
    selectedGalleryId = galleryId;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _mediaPhotoRepository.getByGallery(galleryId),
        _mediaPackRepository.getByGallery(galleryId),
      ]);
      selectedGalleryPhotos = results[0] as List<MediaPhotoModel>;
      selectedGalleryPacks = results[1] as List<MediaPackModel>;
    } catch (err) {
      error = err;
      selectedGalleryPhotos = const <MediaPhotoModel>[];
      selectedGalleryPacks = const <MediaPackModel>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final currentOwnerUid = ownerUid;
    if (currentOwnerUid == null || currentOwnerUid.isEmpty) return;
    await loadForOwnerUid(currentOwnerUid);
  }
}