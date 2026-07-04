// Format du QR de rattachement traceur → admin groupe.
//
// Le QR encode un payload auto-identifiant `maslive-group:{code}?name={nom}`
// pour éviter qu'un QR quelconque scanné ne déclenche un rattachement, et pour
// afficher le nom du groupe en confirmation avant de lier. Le parseur reste
// tolérant: il accepte aussi l'ancienne forme sans nom, une URI `maslive://…`,
// ou un code brut à 6 chiffres.

const String _kGroupQrPrefix = 'maslive-group:';

final RegExp _kSixDigits = RegExp(r'^\d{6}$');

/// Contenu décodé d'un QR de rattachement.
class GroupQrPayload {
  const GroupQrPayload({required this.code, this.groupName});

  /// Code admin à 6 chiffres (adminGroupId).
  final String code;

  /// Nom du groupe (displayName de l'admin), si présent dans le QR.
  final String? groupName;
}

/// Construit la charge utile encodée dans le QR affiché côté admin.
String buildGroupQrPayload(String adminGroupId, {String? groupName}) {
  final code = adminGroupId.trim();
  final name = (groupName ?? '').trim();
  if (name.isEmpty) return '$_kGroupQrPrefix$code';
  return '$_kGroupQrPrefix$code?name=${Uri.encodeComponent(name)}';
}

/// Extrait le code admin (+ nom éventuel) depuis le contenu scanné.
/// Retourne `null` si aucun code valide à 6 chiffres n'est trouvé.
GroupQrPayload? parseGroupQrPayload(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.isEmpty) return null;

  // Retire le préfixe connu.
  if (value.startsWith(_kGroupQrPrefix)) {
    value = value.substring(_kGroupQrPrefix.length).trim();
  } else if (value.startsWith('maslive://group/')) {
    value = value.substring('maslive://group/'.length).trim();
  }

  // Extrait le nom depuis la query `?name=...`.
  String? name;
  final qIndex = value.indexOf('?');
  if (qIndex >= 0) {
    final query = value.substring(qIndex + 1);
    value = value.substring(0, qIndex);
    for (final pair in query.split('&')) {
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final key = pair.substring(0, eq);
      if (key != 'name') continue;
      try {
        final decoded = Uri.decodeComponent(pair.substring(eq + 1)).trim();
        if (decoded.isNotEmpty) name = decoded;
      } catch (_) {
        // Query malformée: on ignore le nom, le code reste exploitable.
      }
    }
  }

  // Ne conserve que les chiffres du code (tolère espaces/séparateurs).
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (_kSixDigits.hasMatch(digits)) {
    return GroupQrPayload(code: digits, groupName: name);
  }
  return null;
}
