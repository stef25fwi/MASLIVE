import 'package:flutter/foundation.dart';

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
  }) : _mediaGalleryRepository =
           mediaGalleryRepository ?? MediaGalleryRepository(),
       _mediaPhotoRepository = mediaPhotoRepository ?? MediaPhotoRepository(),
       _mediaPackRepository = mediaPackRepository ?? MediaPackRepository();

  final MediaGalleryRepository _mediaGalleryRepository;
  final MediaPhotoRepository _mediaPhotoRepository;
  final MediaPackRepository _mediaPackRepository;

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
    photos = const <MediaPhotoModel>[];
    packs = const <MediaPackModel>[];
    notifyListeners();

    try {
      final eventGalleries = await _mediaGalleryRepository.getByEvent(eventId);
      galleries = _applySelectionScope(
        eventGalleries,
        countryId: countryId,
        circuitId: circuitId,
      );
    } catch (err) {
      error = err;
      galleries = const <MediaGalleryModel>[];
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
    photos = const <MediaPhotoModel>[];
    packs = const <MediaPackModel>[];
    notifyListeners();

    try {
      galleries = await _mediaGalleryRepository.getByPhotographer(photographerId);
    } catch (err) {
      error = err;
      galleries = const <MediaGalleryModel>[];
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
      final byCountry = scoped
          .where((gallery) => gallery.linkedCountry?.trim() == countryId.trim())
          .toList(growable: false);
      if (byCountry.isNotEmpty) {
        scoped = byCountry;
      }
    }

    if (circuitId != null && circuitId.trim().isNotEmpty) {
      final byCircuit = scoped
          .where((gallery) => gallery.linkedCircuitId?.trim() == circuitId.trim())
          .toList(growable: false);
      if (byCircuit.isNotEmpty) {
        scoped = byCircuit;
      }
    }

    return scoped;
  }
}