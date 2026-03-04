import 'package:firebase_analytics/firebase_analytics.dart';

class PoiAnalyticsService {
  PoiAnalyticsService._();

  static final PoiAnalyticsService instance = PoiAnalyticsService._();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  Future<void> logPoiPolaroidOpen({
    required String type,
    required bool hasImage,
    String? title,
  }) async {
    try {
      final safeTitle = (title ?? '').trim();
      final params = <String, Object>{
        'type': type.trim().toLowerCase(),
        'has_image': hasImage,
      };

      if (safeTitle.isNotEmpty) {
        params['title'] = safeTitle.substring(
          0,
          safeTitle.length.clamp(0, 80),
        );
      }

      await _analytics.logEvent(
        name: 'poi_polaroid_open',
        parameters: params,
      );
    } catch (_) {
      // Ne doit jamais casser l'UX.
    }
  }
}
