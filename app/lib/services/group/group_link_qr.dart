// Format du QR de rattachement traceur → admin groupe.
//
// Le QR encode un payload auto-identifiant `maslive-group:{code}` pour éviter
// qu'un QR quelconque scanné ne déclenche un rattachement. Le parseur reste
// tolérant: il accepte aussi un code brut à 6 chiffres (QR "code seul").

const String _kGroupQrPrefix = 'maslive-group:';

final RegExp _kSixDigits = RegExp(r'^\d{6}$');

/// Construit la charge utile encodée dans le QR affiché côté admin.
String buildGroupQrPayload(String adminGroupId) {
  return '$_kGroupQrPrefix${adminGroupId.trim()}';
}

/// Extrait un code admin (6 chiffres) depuis le contenu scanné.
///
/// Accepte `maslive-group:123456`, l'ancienne forme d'URI `maslive://group/123456`,
/// ou un code brut `123456`. Retourne `null` si aucun code valide n'est trouvé.
String? parseGroupQrPayload(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.isEmpty) return null;

  if (value.startsWith(_kGroupQrPrefix)) {
    value = value.substring(_kGroupQrPrefix.length).trim();
  } else if (value.startsWith('maslive://group/')) {
    value = value.substring('maslive://group/'.length).trim();
  }

  // Ne conserve que les chiffres (tolère espaces/séparateurs éventuels).
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (_kSixDigits.hasMatch(digits)) return digits;
  return null;
}
