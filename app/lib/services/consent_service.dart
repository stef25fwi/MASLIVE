import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gère le consentement de l'utilisateur aux traceurs de mesure d'audience
/// (Firebase Analytics), conformément à la doctrine CNIL / ePrivacy.
///
/// Principe : la collecte est **désactivée par défaut** et n'est activée que
/// si l'utilisateur a explicitement consenti. Le choix est mémorisé
/// localement (SharedPreferences).
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  static const String _kAnalyticsKey = 'consent_analytics_v1';

  /// `null` = pas encore décidé (la bannière doit s'afficher).
  /// `true` = consenti, `false` = refusé.
  final ValueNotifier<bool?> analyticsConsent = ValueNotifier<bool?>(null);

  bool get decided => analyticsConsent.value != null;

  /// À appeler une fois Firebase initialisé : charge le choix mémorisé et
  /// applique l'état à Firebase Analytics (désactivé tant que non consenti).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      analyticsConsent.value =
          prefs.containsKey(_kAnalyticsKey) ? prefs.getBool(_kAnalyticsKey) : null;
    } catch (_) {
      analyticsConsent.value = null;
    }
    await _applyToAnalytics();
  }

  /// Enregistre le choix de l'utilisateur et l'applique immédiatement.
  Future<void> setAnalyticsConsent(bool granted) async {
    analyticsConsent.value = granted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAnalyticsKey, granted);
    } catch (_) {
      // non bloquant
    }
    await _applyToAnalytics();
  }

  Future<void> _applyToAnalytics() async {
    final granted = analyticsConsent.value == true;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(granted);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('⚠️ ConsentService: setAnalyticsCollectionEnabled failed: $error');
      }
    }
  }
}
