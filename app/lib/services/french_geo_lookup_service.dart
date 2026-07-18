import 'dart:convert';

import 'package:http/http.dart' as http;

/// Résultat de résolution ville/région à partir d'un code postal français,
/// via l'API officielle geo.api.gouv.fr (aucune clé requise).
class FrenchCommuneMatch {
  const FrenchCommuneMatch({required this.city, required this.region});

  final String city;
  final String region;

  bool get isEmpty => city.isEmpty && region.isEmpty;
}

/// Résout ville + région à partir d'un code postal français via l'API
/// officielle data.gouv.fr (geo.api.gouv.fr/communes), sans clé API.
///
/// Fallback DOM codé en dur (971-976) si l'API est indisponible ou ne
/// retourne aucun résultat, pour ne jamais bloquer un formulaire.
class FrenchGeoLookupService {
  const FrenchGeoLookupService({http.Client? client}) : _client = client;

  final http.Client? _client;

  static final RegExp _postalCodeRegExp = RegExp(r'^\d{5}$');

  bool isValidPostalCode(String value) => _postalCodeRegExp.hasMatch(value.trim());

  /// [preferredCity] permet de désambiguïser un code postal partagé par
  /// plusieurs communes (ex: certains CP ruraux) en choisissant la commune
  /// dont le nom se rapproche le plus de la ville déjà saisie.
  Future<FrenchCommuneMatch> lookupByPostalCode(
    String postalCode, {
    String preferredCity = '',
  }) async {
    final normalized = postalCode.trim();
    if (!_postalCodeRegExp.hasMatch(normalized)) {
      return FrenchCommuneMatch(city: '', region: _domRegionFallback(normalized));
    }

    try {
      final uri = Uri.https(
        'geo.api.gouv.fr',
        '/communes',
        <String, String>{
          'codePostal': normalized,
          'fields': 'nom,region',
          'format': 'json',
        },
      );

      final response = await _get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return FrenchCommuneMatch(city: '', region: _domRegionFallback(normalized));
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return FrenchCommuneMatch(city: '', region: _domRegionFallback(normalized));
      }

      final normalizedPreferredCity = _normalizeText(preferredCity);
      Map<String, dynamic>? selected;
      for (final row in decoded) {
        if (row is! Map<String, dynamic>) continue;
        final rowCity = _normalizeText(row['nom']?.toString() ?? '');
        if (normalizedPreferredCity.isNotEmpty && rowCity == normalizedPreferredCity) {
          selected = row;
          break;
        }
        selected ??= row;
      }

      final city = selected?['nom']?.toString().trim() ?? '';
      final regionField = selected?['region'];
      final region = regionField is Map<String, dynamic>
          ? (regionField['nom']?.toString().trim() ?? '')
          : '';

      if (city.isEmpty && region.isEmpty) {
        return FrenchCommuneMatch(city: '', region: _domRegionFallback(normalized));
      }

      return FrenchCommuneMatch(
        city: city,
        region: region.isNotEmpty ? region : _domRegionFallback(normalized),
      );
    } catch (_) {
      return FrenchCommuneMatch(city: '', region: _domRegionFallback(normalized));
    }
  }

  Future<http.Response> _get(Uri uri) {
    final client = _client;
    if (client != null) {
      return client.get(uri, headers: const <String, String>{'accept': 'application/json'});
    }
    return http.get(uri, headers: const <String, String>{'accept': 'application/json'});
  }

  String _domRegionFallback(String postalCode) {
    if (postalCode.startsWith('971')) return 'Guadeloupe';
    if (postalCode.startsWith('972')) return 'Martinique';
    if (postalCode.startsWith('973')) return 'Guyane';
    if (postalCode.startsWith('974')) return 'La Réunion';
    if (postalCode.startsWith('976')) return 'Mayotte';
    return '';
  }

  String _normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[\s\-']+"), ' ')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c');
  }
}
