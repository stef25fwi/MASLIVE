import '../../data/models/media_gallery_model.dart';
import '../models/photo_shop_navigation_context.dart';

class GalleryRelevanceService {
  const GalleryRelevanceService();

  List<MediaGalleryModel> rank({
    required Iterable<MediaGalleryModel> galleries,
    required PhotoShopNavigationContext context,
    DateTime? now,
    Set<String> officialPhotographerIds = const <String>{},
  }) {
    final referenceNow = now ?? DateTime.now();
    final result = galleries.toList(growable: false);
    result.sort((a, b) {
      final scoreA = _score(a, context, referenceNow, officialPhotographerIds);
      final scoreB = _score(b, context, referenceNow, officialPhotographerIds);
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) return byScore;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return result;
  }

  int _score(
    MediaGalleryModel gallery,
    PhotoShopNavigationContext context,
    DateTime now,
    Set<String> officialPhotographerIds,
  ) {
    var score = 0;
    if (_same(gallery.linkedCircuitId, context.selectedCircuitId)) score += 1000;
    if (_same(gallery.linkedCountry, context.selectedCountryId)) score += 150;
    if (_same(gallery.eventId, context.selectedEventId)) score += 300;
    if (_same(gallery.photographerId, context.selectedPhotographerId)) {
      score += 250;
    }
    if (officialPhotographerIds.contains(gallery.photographerId)) score += 120;

    final referenceDate = context.selectedEventDate;
    if (referenceDate != null) {
      final distance = gallery.updatedAt.difference(referenceDate).inHours.abs();
      score += (240 - distance).clamp(0, 240);
    }

    final freshnessHours = now.difference(gallery.updatedAt).inHours.abs();
    score += (72 - freshnessHours).clamp(0, 72);
    return score;
  }

  bool _same(String? left, String? right) {
    final a = left?.trim();
    final b = right?.trim();
    return a != null && a.isNotEmpty && b != null && b.isNotEmpty && a == b;
  }
}
