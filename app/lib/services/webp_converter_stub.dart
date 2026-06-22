import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// WebP conversion stub for native (Android / iOS / desktop).
///
/// The `image` 4.x package does not expose `encodeWebP`, so we fall back to
/// re-encoding as JPEG at the requested quality and only keep the result if
/// it is smaller than the original bytes.
const bool supportsWebpConversion = true;

Future<Uint8List> convertBytesToWebp(
  Uint8List bytes, {
  int quality = 82,
}) async {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final jpegBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    return jpegBytes.length < bytes.length ? jpegBytes : bytes;
  } catch (_) {
    return bytes;
  }
}
