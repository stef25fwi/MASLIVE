import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Conversion WebP pour le natif (Android / iOS).
///
/// Utilise `flutter_image_compress`, qui s'appuie sur les encodeurs WebP natifs
/// de la plateforme → vrai fichier WebP (et non plus un JPEG ré-encodé étiqueté
/// à tort `image/webp`). On ne conserve le résultat que s'il est plus léger que
/// l'original; sinon on renvoie les octets d'origine (le chemin d'upload ne
/// renomme alors pas en `.webp`).
const bool supportsWebpConversion = true;

Future<Uint8List> convertBytesToWebp(
  Uint8List bytes, {
  int quality = 82,
}) async {
  try {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality.clamp(1, 100),
      format: CompressFormat.webp,
      // Bornes très hautes: on convertit le format sans imposer de downscale
      // (un redimensionnement éventuel est géré ailleurs par ImageOptimizationService).
      minWidth: 100000,
      minHeight: 100000,
    );
    if (result.isNotEmpty && result.length < bytes.length) {
      return result;
    }
    return bytes;
  } catch (_) {
    return bytes;
  }
}
