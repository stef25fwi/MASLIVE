String _twoLetterUpper(String s) {
  final trimmed = s.trim();
  if (trimmed.length != 2) return '';
  final upper = trimmed.toUpperCase();
  final a = upper.codeUnitAt(0);
  final b = upper.codeUnitAt(1);
  bool isUpperAsciiLetter(int c) => c >= 65 && c <= 90;
  return (isUpperAsciiLetter(a) && isUpperAsciiLetter(b)) ? upper : '';
}

/// Retourne l'emoji drapeau à partir d'un code ISO-3166 alpha-2 (ex: FR, GP).
///
/// - Retourne '' si invalide/inconnu.
String countryFlagEmojiFromIso2(String? iso2) {
  if (iso2 == null) return '';
  final code = _twoLetterUpper(iso2);
  if (code.isEmpty) return '';

  // Regional indicator symbols start at 0x1F1E6 ('A')
  const base = 0x1F1E6;
  final first = base + (code.codeUnitAt(0) - 65);
  final second = base + (code.codeUnitAt(1) - 65);
  return String.fromCharCode(first) + String.fromCharCode(second);
}

String _norm(String? s) {
  return (s ?? '').trim().toLowerCase();
}

/// Heuristique légère pour déduire un code ISO2 depuis les données MarketMap.
///
/// - Si `id` ressemble à un ISO2 => utilisé.
/// - Sinon fallback via slug/nom sur quelques pays/dom-tom courants.
String guessIso2FromMarketMapCountry({
  required String id,
  required String slug,
  required String name,
}) {
  final idCode = _twoLetterUpper(id);
  if (idCode.isNotEmpty) return idCode;

  final key = _norm(slug).isNotEmpty ? _norm(slug) : _norm(name);
  if (key.isEmpty) return '';

  const map = <String, String>{
    'fr': 'FR',
    'france': 'FR',
    'gp': 'GP',
    'guadeloupe': 'GP',
    'mq': 'MQ',
    'martinique': 'MQ',
    're': 'RE',
    'reunion': 'RE',
    'réunion': 'RE',
    'gf': 'GF',
    'guyane': 'GF',
    'yt': 'YT',
    'mayotte': 'YT',
    'be': 'BE',
    'belgique': 'BE',
    'ch': 'CH',
    'suisse': 'CH',
    'ca': 'CA',
    'canada': 'CA',
    'us': 'US',
    'usa': 'US',
    'united states': 'US',
    'etats-unis': 'US',
    'états-unis': 'US',
  };

  return map[key] ?? '';
}

/// Formatage d'un libellé pays avec drapeau si possible.
///
/// Exemple: "🇬🇵 Guadeloupe".
String formatCountryLabelWithFlag({required String name, String? iso2}) {
  final flag = countryFlagEmojiFromIso2(iso2);
  if (flag.isEmpty) return name;
  return '$flag $name';
}

/// Même chose mais en devinant le code à partir du nom (fallback léger).
String formatCountryNameWithFlag(String name) {
  final n = _norm(name);
  const nameToIso2 = <String, String>{
    'france': 'FR',
    'guadeloupe': 'GP',
    'martinique': 'MQ',
    'reunion': 'RE',
    'réunion': 'RE',
    'guyane': 'GF',
    'mayotte': 'YT',
    'belgique': 'BE',
    'suisse': 'CH',
    'united states': 'US',
    'usa': 'US',
    'etats-unis': 'US',
    'états-unis': 'US',
    'canada': 'CA',
  };

  final iso2 = nameToIso2[n] ?? '';
  return formatCountryLabelWithFlag(name: name, iso2: iso2);
}
