import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Conversion WebP côté natif (Android / iOS / desktop).
///
/// Utilise le package `image` (4.x) qui supporte l'encodage WebP.
/// On compare la taille et ne garde le WebP que s'il est plus léger.
/// En cas d'erreur, les bytes originaux sont retournés sans plantage.
const bool supportsWebpConversion = true;

Future<Uint8List> convertBytesToWebp(
  Uint8List bytes, {
  int quality = 82,
}) async {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final webpBytes = Uint8List.fromList(
      img.encodeWebP(image, quality: quality),
    );
    // Lossless WebP peut être plus lourd qu'un JPEG — ne garder que si plus léger.
    return webpBytes.length < bytes.length ? webpBytes : bytes;
  } catch (_) {
    return bytes;
  }
}
