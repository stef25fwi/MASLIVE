import 'package:flutter/foundation.dart';

import '../../core/pagination/media_gallery_pagination.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/repositories/media_gallery_repository.dart';
import '../../data/repositories/media_pack_repository.dart';
import '../../data/repositories/media_photo_repository.dart';

class MediaMarketplaceCatalogController extends ChangeNotifier {
  MediaMarketplaceCatalogController({
    MediaGalleryRepository? mediaGalleryRepository,
    MediaPhotoRepository? mediaPhotoRepository,
    MediaPackRepository? mediaPackRepository,
  })  : _mediaGalleryRepository =
            mediaGalleryRepository ?? MediaGalleryRepository(),
        _mediaPhotoRepository = mediaPhotoRepository ?? MediaPhotoRepository(),
        _mediaPackRepository = mediaPackRepository ?? MediaPackRepository();

  final MediaGalleryRepository _mediaGalleryRepository;
  final MediaPhotoRepository _mediaPhotoRepository;
  final MediaPackRepository _mediaPackRepository;
  final MediaGalleryPaginationState<MediaPhotoModel> _photoPagination =
      MediaGalleryPaginationState<MediaPhotoModel>();

  bool loading = false;
  Object? error;
  String? currentCountryId;
  String? currentEventId;
  String? currentPhotographerId;
  String? currentCircuitId;
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
  }) async {
    loading = true;
    error = null;
    currentCountryId = countryId;
    currentEventId = eventId;
    currentPhotographerId = null;
    currentCircuitId = circuitId;
    selectedGalleryId = null;
    _resetPhotos();
    packs = const <MediaPackModel>[];
    notifyListeners();

    try {
      final eventGalleries = await _mediaGalleryRepository.getByEvent(eventId);
      galleries = _applySelectionScope(
        eventGalleries,
        countryId: countryId,
        circuitId: circuitId,
      );
      await _selectFirstGalleryByDefault();
    } catch (err) {
      error = err;
      galleries = const <MediaGalleryModel>[];
      _resetPhotos();
      packs = const <MediaPackModel>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadPhotographerGalleries(String photographerId) async {
    loading = true;
    error = null;
    currentCountryId = null;
    currentPhotographerId = photographerId;
    currentEventId = null;
    currentCircuitId = null;
    selectedGalleryId = null;
    _resetPhotos();
    packs = const <MediaPackModel>[];
    notifyListeners();

    try {
      galleries =
          await _mediaGalleryRepository.getByPhotographer(photographerId);
      await _selectFirstGalleryByDefault();
    } catch (err) {
      error = err;
      galleries = const <MediaGalleryModel>[];
      _resetPhotos();
      packs = const <MediaPackModel>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _selectFirstGalleryByDefault() async {
    if (galleries.isEmpty) return;
    selectedGalleryId = galleries.first.galleryId;
    await _loadSelectedGallery(reset: true);
  }

  Future<void> selectGallery(String galleryId) async {
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
