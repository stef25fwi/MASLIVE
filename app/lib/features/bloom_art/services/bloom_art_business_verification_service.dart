import 'dart:convert';

import 'package:http/http.dart' as http;

class BloomArtBusinessVerificationResult {
  const BloomArtBusinessVerificationResult({
    required this.siret,
    required this.siren,
    required this.denomination,
    required this.nafCode,
    required this.address,
    required this.postalCode,
    required this.city,
    required this.region,
    required this.isValid,
    this.errorMessage,
  });

  final String siret;
  final String siren;
  final String denomination;
  final String nafCode;
  final String address;
  final String postalCode;
  final String city;
  final String region;
  final bool isValid;
  final String? errorMessage;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'siret': siret,
      'siren': siren,
      'denomination': denomination,
      'nafCode': nafCode,
      'address': address,
      'postalCode': postalCode,
      'city': city,
      'region': region,
      'isValid': isValid,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}

class BloomArtBusinessVerificationService {
  const BloomArtBusinessVerificationService({http.Client? client}) : _client = client;

  final http.Client? _client;

  static final RegExp _siretRegExp = RegExp(r'^\d{14}$');

  String normalizeSiret(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  bool isValidSiretShape(String raw) => _siretRegExp.hasMatch(normalizeSiret(raw));

  Future<BloomArtBusinessVerificationResult> verifySiret(String rawSiret) async {
    final siret = normalizeSiret(rawSiret);
    if (!_siretRegExp.hasMatch(siret)) {
      return _invalid(
        siret: siret,
        errorMessage: 'Le SIRET doit contenir 14 chiffres.',
      );
    }

    if (!_passesLuhn(siret)) {
      return _invalid(
        siret: siret,
        errorMessage: 'Le numéro SIRET ne respecte pas la clé de contrôle.',
      );
    }

    final enterprise = await _fetchEnterpriseBySiret(siret);
    if (enterprise == null) {
      return _invalid(
        siret: siret,
        errorMessage: 'Aucune entreprise française trouvée pour ce SIRET.',
      );
    }

    final returnedSiret = _firstNonEmpty(<String>[
      _stringValue(enterprise, const <String>['siret']),
      _stringValue(enterprise, const <String>['siege.siret']),
      _stringValue(enterprise, const <String>['matching_etablissements.0.siret']),
    ]);

    if (returnedSiret.isNotEmpty && normalizeSiret(returnedSiret) != siret) {
      return _invalid(
        siret: siret,
        errorMessage: 'Le résultat API ne correspond pas exactement au SIRET saisi.',
      );
    }

    final address = _firstNonEmpty(<String>[
      _stringValue(enterprise, const <String>['siege.adresse']),
      _stringValue(enterprise, const <String>['siege.geo_adresse']),
      _stringValue(enterprise, const <String>['matching_etablissements.0.adresse']),
      _stringValue(enterprise, const <String>['adresse']),
    ]);
    final postalCode = _firstNonEmpty(<String>[
      _stringValue(enterprise, const <String>['siege.code_postal']),
      _stringValue(enterprise, const <String>['matching_etablissements.0.code_postal']),
      _stringValue(enterprise, const <String>['code_postal']),
    ]);
    final city = _firstNonEmpty(<String>[
      _stringValue(enterprise, const <String>['siege.libelle_commune']),
      _stringValue(enterprise, const <String>['siege.commune']),
      _stringValue(enterprise, const <String>['matching_etablissements.0.commune']),
      _stringValue(enterprise, const <String>['commune']),
    ]);
    final region = await _resolveRegion(postalCode: postalCode, city: city);

    return BloomArtBusinessVerificationResult(
      siret: siret,
      siren: _firstNonEmpty(<String>[
        _stringValue(enterprise, const <String>['siren']),
        siret.substring(0, 9),
      ]),
      denomination: _firstNonEmpty(<String>[
        _stringValue(enterprise, const <String>['nom_complet']),
        _stringValue(enterprise, const <String>['nom_raison_sociale']),
        _stringValue(enterprise, const <String>['denomination']),
        _stringValue(enterprise, const <String>['siege.enseigne']),
      ]),
      nafCode: _firstNonEmpty(<String>[
        _stringValue(enterprise, const <String>['activite_principale']),
        _stringValue(enterprise, const <String>['naf']),
        _stringValue(enterprise, const <String>['code_naf']),
        _stringValue(enterprise, const <String>['siege.activite_principale']),
      ]),
      address: address,
      postalCode: postalCode,
      city: city,
      region: region,
      isValid: true,
    );
  }

  Future<Map<String, dynamic>?> _fetchEnterpriseBySiret(String siret) async {
    final uri = Uri.https(
      'recherche-entreprises.api.gouv.fr',
      '/search',
      <String, String>{'q': siret, 'per_page': '1'},
    );

    final response = await _get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final results = decoded['results'];
    if (results is! List || results.isEmpty) return null;

    final first = results.first;
    if (first is Map<String, dynamic>) return first;
    return null;
  }

  Future<String> _resolveRegion({required String postalCode, required String city}) async {
    final normalizedPostalCode = postalCode.trim();
    if (normalizedPostalCode.isEmpty) return _domRegionFallback(postalCode);

    try {
      final uri = Uri.https(
        'geo.api.gouv.fr',
        '/communes',
        <String, String>{
          'codePostal': normalizedPostalCode,
          'fields': 'nom,code,codesPostaux,departement,region',
          'format': 'json',
          'geometry': 'centre',
        },
      );
      final response = await _get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _domRegionFallback(postalCode);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return _domRegionFallback(postalCode);

      final normalizedCity = _normalizeText(city);
      Map<String, dynamic>? selected;
      for (final row in decoded) {
        if (row is! Map<String, dynamic>) continue;
        final rowCity = _normalizeText(row['nom']?.toString() ?? '');
        if (normalizedCity.isNotEmpty && rowCity == normalizedCity) {
          selected = row;
          break;
        }
        selected ??= row;
      }
      final region = selected?['region'];
      if (region is Map<String, dynamic>) {
        final name = region['nom']?.toString().trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    } catch (_) {
      return _domRegionFallback(postalCode);
    }

    return _domRegionFallback(postalCode);
  }

  Future<http.Response> _get(Uri uri) {
    final client = _client;
    if (client != null) {
      return client.get(uri, headers: const <String, String>{'accept': 'application/json'});
    }
    return http.get(uri, headers: const <String, String>{'accept': 'application/json'});
  }

  BloomArtBusinessVerificationResult _invalid({
    required String siret,
    required String errorMessage,
  }) {
    return BloomArtBusinessVerificationResult(
      siret: siret,
      siren: siret.length >= 9 ? siret.substring(0, 9) : '',
      denomination: '',
      nafCode: '',
      address: '',
      postalCode: '',
      city: '',
      region: '',
      isValid: false,
      errorMessage: errorMessage,
    );
  }

  bool _passesLuhn(String value) {
    var sum = 0;
    var shouldDouble = false;
    for (var i = value.length - 1; i >= 0; i--) {
      var digit = int.parse(value[i]);
      if (shouldDouble) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      shouldDouble = !shouldDouble;
    }
    return sum % 10 == 0;
  }

  String _stringValue(Map<String, dynamic> source, List<String> paths) {
    for (final path in paths) {
      final value = _readPath(source, path);
      final stringValue = value?.toString().trim() ?? '';
      if (stringValue.isNotEmpty && stringValue != 'null') return stringValue;
    }
    return '';
  }

  Object? _readPath(Map<String, dynamic> source, String path) {
    Object? current = source;
    for (final part in path.split('.')) {
      if (current is Map<String, dynamic>) {
        current = current[part];
        continue;
      }
      if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
        continue;
      }
      return null;
    }
    return current;
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final clean = value.trim();
      if (clean.isNotEmpty) return clean;
    }
    return '';
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
