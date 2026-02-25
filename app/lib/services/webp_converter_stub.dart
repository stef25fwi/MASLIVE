import 'dart:typed_data';

/// Conversion WebP côté client.
///
/// Par défaut (non-web), on ne convertit pas: on renvoie les bytes originaux.
/// (L'encodage WebP nécessite une implémentation native ou navigateur.)
const bool supportsWebpConversion = false;

Future<Uint8List> convertBytesToWebp(
  Uint8List bytes, {
  int quality = 88,
}) async {
  return bytes;
}
