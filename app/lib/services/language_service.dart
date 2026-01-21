import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion des langues et locales
class LanguageService extends GetxService {
  static const String _languageKey = 'selected_language';
  
  final Rx<Locale> _locale = Locale('fr').obs;
  late SharedPreferences _prefs;

  Locale get locale => _locale.value;
  String get currentLanguageCode => _locale.value.languageCode;

  // Langues supportées
  static const List<Locale> supportedLocales = [
    Locale('fr'), // Français
    Locale('en'), // Anglais
    Locale('es'), // Espagnol
  ];

  static const Map<String, String> languageNames = {
    'fr': 'Français',
    'en': 'English',
    'es': 'Español',
  };

  static const Map<String, String> languageFlagEmojis = {
    'fr': '🇫🇷',
    'en': '🇬🇧',
    'es': '🇪🇸',
  };

  @override
  Future<LanguageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Charger la langue sauvegardée
    final savedLanguage = _prefs.getString(_languageKey);
    if (savedLanguage != null) {
      _locale.value = Locale(savedLanguage);
    } else {
      // Utiliser la langue du système ou par défaut français
      final deviceLocale = Get.deviceLocale;
      if (deviceLocale != null && supportedLocales.contains(deviceLocale)) {
        _locale.value = deviceLocale;
      } else {
        _locale.value = const Locale('fr');
      }
    }
    
    return this;
  }

  /// Change la langue
  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLocales.any((locale) => locale.languageCode == languageCode)) {
      throw Exception('Langue non supportée: $languageCode');
    }

    _locale.value = Locale(languageCode);
    Get.updateLocale(Locale(languageCode));
    
    // Sauvegarder la langue
    await _prefs.setString(_languageKey, languageCode);
  }

  /// Obtenir le nom de la langue
  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? 'Unknown';
  }

  /// Obtenir le drapeau emoji
  String getLanguageFlag(String languageCode) {
    return languageFlagEmojis[languageCode] ?? '';
  }

  /// Obtenir la liste des langues disponibles
  List<Map<String, String>> getAvailableLanguages() {
    return supportedLocales.map((locale) {
      final code = locale.languageCode;
      return {
        'code': code,
        'name': getLanguageName(code),
        'flag': getLanguageFlag(code),
      };
    }).toList();
  }
}
