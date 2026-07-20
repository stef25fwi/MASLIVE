import 'package:flutter/foundation.dart';

import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/repositories/media_gallery_repository.dart';
import '../../data/repositories/media_pack_repository.dart';
import '../../data/repositories/media_photo_repository.dart';
import '../../domain/models/photo_shop_navigation_context.dart';
import '../../domain/services/gallery_relevance_service.dart';

class MediaMarketplaceCatalogController extends ChangeNotifier {
  MediaMarketplaceCatalogController({
    MediaGalleryRepository? mediaGalleryRepository,
    MediaPhotoRepository? mediaPhotoRepository,
    MediaPackRepository? mediaPackRepository,
    GalleryRelevanceService? galleryRelevanceService,
  })  : _mediaGalleryRepository =
            mediaGalleryRepository ?? MediaGalleryRepository(),
        _mediaPhotoRepository = mediaPhotoRepository ?? MediaPhotoRepository(),
        _mediaPackRepository = mediaPackRepository ?? MediaPackRepository(),
        _galleryRelevanceService =
            galleryRelevanceService ?? const GalleryRelevanceService();

  final MediaGalleryRepository _mediaGalleryRepository;
  final MediaPhotoRepository _mediaPhotoRepository;
  final MediaPackRepository _mediaPackRepository;
  final GalleryRelevanceService _galleryRelevanceService;

  bool loading = false;
  Object? error;
  String? currentCountryId;
  String? currentEventId;
  String? currentPhotographerId;
  String? currentCircuitId;
  PhotoShopNavigationContext currentContext =
      const PhotoShopNavigationContext();
  String? selectedGalleryId;
  List<MediaGalleryModel> galleries = const <MediaGalleryModel>[];
  List<MediaPhotoModel> photos = const <MediaPhotoModel>[];
  List<MediaPackModel> packs = const <MediaPackModel>[];

  Future<void> loadEventGalleries(
    String eventId, {
    String? countryId,
    String? circuitId,
  }) {
    return loadContextGalleries(
      PhotoShopNavigationContext(
        selectedEventId: eventId,
        selectedCountryId: countryId,
        selectedCircuitId: circuitId,
      ),
    );
  }

  Future<void> loadContextGalleries(
    PhotoShopNavigationContext context, {
    Set<String> officialPhotographerIds = const <String>{},
  }) async {
    loading = true;
    error = null;
    currentContext = context;
    currentCountryId = context.selectedCountryId;
    currentEventId = context.selectedEventId;
    currentPhotographerId = context.selectedPhotographerId;
    currentCircuitId = context.selectedCircuitId;
    selectedGalleryId = null;
    photos = const <MediaPhotoModel>[];
    packs = const <MediaPackModel>[];
    notifyListeners();

    try {
      final eventId = context.selectedEventId;
      final photographerId = context.selectedPhotographerId;
      final source = eventId != null && eventId.trim().isNotEmpty
          ? await _mediaGalleryRepository.getByEvent(eventId)
          : photographerId != null && photographerId.trim().isNotEmpty
              ? await _mediaGalleryRepository.getByPhotographer(photographerId)
              : const <MediaGalleryModel>[];
      final scoped = _applySelectionScope(
        source,
        countryId: context.selectedCountryId,
        circuitId: context.selectedCircuitId,
      );
      galleries = _galleryRelevanceService.rank(
        galleries: scoped,
        context: context,
        officialPhotographerIds: officialPhotographerIds,
      );
      await _selectFirstGalleryByDefault();
    } catch (err) {
      error = err;
      galleries = const <MediaGalleryModel>[];
      photos = const <MediaPhotoModel>[];
      packs = const <MediaPackModel>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadPhotographerGalleries(String photographerId) {
    return loadContextGalleries(
      PhotoShopNavigationContext(selectedPhotographerId: photographerId),
    );
  }

  Future<void> _selectFirstGalleryByDefault() async {
    if (galleries.isEmpty) {
      selectedGalleryId = null;
      photos = const <MediaPhotoModel>[];
      packs = const <MediaPackModel>[];
      return;
    }
    selectedGalleryId = galleries.first.galleryId;
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _mediaPhotoRepository.getPublishedByGallery(selectedGalleryId!),
      _mediaPackRepository.getActiveByGallery(selectedGalleryId!),
    ]);
    photos = results[0] as List<MediaPhotoModel>;
    packs = results[1] as List<MediaPackModel>;
  }

  Future<void> selectGallery(String galleryId) async {
    if (!galleries.any((gallery) => gallery.galleryId == galleryId)) {
      throw StateError('Galerie indisponible dans le contexte sélectionné.');
    }
    loading = true;
    error = null;
    selectedGalleryId = galleryId;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _mediaPhotoRepository.getPublishedByGallery(galleryId),
        _mediaPackRepository.getActiveByGallery(galleryId),
      ]);
      photos = results[0] as List<MediaPhotoModel>;
      packs = results[1] as List<MediaPackModel>;
    } catch (err) {
      error = err;
      photos = const <MediaPhotoModel>[];
      packs = const <MediaPackModel>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    selectedGalleryId = null;
    photos = const <MediaPhotoModel>[];
    packs = const <MediaPackModel>[];
    notifyListeners();
  }

  List<MediaGalleryModel> _applySelectionScope(
    List<MediaGalleryModel> source, {
    String? countryId,
    String? circuitId,
  }) {
    var scoped = source;

    if (countryId != null && countryId.trim().isNotEmpty) {
      scoped = scoped
          .where(
            (gallery) => gallery.linkedCountry?.trim() == countryId.trim(),
          )
          .toList(growable: false);
    }

    if (circuitId != null && circuitId.trim().isNotEmpty) {
      scoped = scoped
          .where(
            (gallery) => gallery.linkedCircuitId?.trim() == circuitId.trim(),
          )
          .toList(growable: false);
    }

    return scoped;
  }
}
