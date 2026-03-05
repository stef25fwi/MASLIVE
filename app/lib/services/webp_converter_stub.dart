import 'dart:typed_data';

/// Conversion WebP côté client.
///
/// Par défaut (non-web), on ne convertit pas: on renvoie les bytes originaux.
/// (L'encodage WebP est géré côté Web par canvas.)
const bool supportsWebpConversion = false;

Future<Uint8List> convertBytesToWebp(
  Uint8List bytes, {
  int quality = 88,
}) async {
  return bytes;
}
