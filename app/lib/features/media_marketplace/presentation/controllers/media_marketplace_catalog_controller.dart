import 'package:flutter/foundation.dart';

import '../../core/pagination/media_gallery_pagination.dart';
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
  final MediaGalleryPaginationState<MediaPhotoModel> _photoPagination =
      MediaGalleryPaginationState<MediaPhotoModel>();

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

  bool get loadingMorePhotos => _photoPagination.loading;
  bool get hasMorePhotos => _photoPagination.hasMore;
  bool get canLoadMorePhotos => _photoPagination.canLoadMore;

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
    galleries = const <MediaGalleryModel>[];
    _resetPhotos();
    packs = const <MediaPackModel>[];
    notifyListeners();

    try {
      final eventId = context.selectedEventId?.trim();
      final photographerId = context.selectedPhotographerId?.trim();
      final source = eventId != null && eventId.isNotEmpty
          ? await _mediaGalleryRepository.getByEvent(eventId)
          : photographerId != null && photographerId.isNotEmpty
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
      selectedGalleryId = null;
      _resetPhotos();
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
      _resetPhotos();
      packs = const <MediaPackModel>[];
      return;
    }
    selectedGalleryId = galleries.first.galleryId;
    await _loadSelectedGallery(reset: true);
  }

  Future<void> selectGallery(String galleryId) async {
    if (!galleries.any((gallery) => gallery.galleryId == galleryId)) {
      throw StateError('Galerie indisponible dans le contexte sélectionné.');
    }
    if (selectedGalleryId == galleryId && photos.isNotEmpty) return;

    loading = true;
    error = null;
    selectedGalleryId = galleryId;
    _resetPhotos();
    notifyListeners();

    try {
      await _loadSelectedGallery(reset: true);
    } catch (err) {
      error = err;
      _resetPhotos();
      packs = const <MediaPackModel>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePhotos() async {
    final galleryId = selectedGalleryId;
    if (galleryId == null || galleryId.isEmpty) return;
    if (!_photoPagination.beginLoad()) return;
    notifyListeners();

    try {
      final page = await _mediaPhotoRepository.getPublishedPageByGallery(
        galleryId,
        cursor: _photoPagination.cursor,
        pageSize: _photoPagination.pageSize,
      );
      if (selectedGalleryId != galleryId) {
        _photoPagination.failLoad();
        return;
      }
      _photoPagination.completePage(page, idOf: (photo) => photo.photoId);
      photos = _photoPagination.items;
    } catch (err) {
      _photoPagination.failLoad();
      error = err;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadSelectedGallery({required bool reset}) async {
    final galleryId = selectedGalleryId;
    if (galleryId == null || galleryId.isEmpty) return;
    if (reset) _resetPhotos();

    final packsFuture = _mediaPackRepository.getActiveByGallery(galleryId);
    await loadMorePhotos();
    if (selectedGalleryId != galleryId) return;
    packs = await packsFuture;
  }

  void clearSelection() {
    selectedGalleryId = null;
    _resetPhotos();
    packs = const <MediaPackModel>[];
    notifyListeners();
  }

  void _resetPhotos() {
    _photoPagination.reset();
    photos = const <MediaPhotoModel>[];
  }

  List<MediaGalleryModel> _applySelectionScope(
    List<MediaGalleryModel> source, {
    String? countryId,
    String? circuitId,
  }) {
    var scoped = source;

    if (countryId != null && countryId.trim().isNotEmpty) {
      final byCountry = scoped
          .where(
            (gallery) => gallery.linkedCountry?.trim() == countryId.trim(),
          )
          .toList(growable: false);
      if (byCountry.isNotEmpty) scoped = byCountry;
    }

    if (circuitId != null && circuitId.trim().isNotEmpty) {
      final byCircuit = scoped
          .where(
            (gallery) => gallery.linkedCircuitId?.trim() == circuitId.trim(),
          )
          .toList(growable: false);
      if (byCircuit.isNotEmpty) scoped = byCircuit;
    }

    return scoped;
  }
}
