// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

const bool supportsWebpConversion = true;

/// Délai maximal accordé à chaque étape asynchrone de la conversion.
///
/// Safari (notamment sur iPad) peut ne jamais émettre `onLoad`/`onLoadEnd`
/// pour un `ImageElement`/`FileReader` créés depuis un blob. Sans borne de
/// temps, `await img.onLoad.first` reste en attente indéfiniment et bloque
/// tout l'upload (l'image n'est jamais envoyée). On borne donc chaque étape
/// et on lève une exception en cas d'expiration: l'appelant retombe alors sur
/// les octets d'origine et poursuit l'upload.
const Duration _stepTimeout = Duration(seconds: 8);

Future<Uint8List> convertBytesToWebp(
  Uint8List bytes, {
  int quality = 88,
}) async {
  final q = quality.clamp(0, 100) / 100.0;

  final blob = html.Blob(<dynamic>[bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  try {
    final img = html.ImageElement(src: url);
    await _waitImageDecoded(img);

    final width = img.naturalWidth;
    final height = img.naturalHeight;

    if (width <= 0 || height <= 0) {
      throw StateError('Image invalide (dimensions nulles)');
    }

    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;
    ctx.drawImage(img, 0, 0);

    final webpBlob = await _canvasToBlob(canvas, 'image/webp', q);
    if (webpBlob == null) {
      throw StateError('Conversion WebP: toBlob a renvoyé null');
    }
    final webpBytes = await _blobToBytes(webpBlob);
    return webpBytes;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

/// Attend que l'image soit décodée, en faisant la course entre `onLoad`,
/// `onError` et un délai maximal. Ne reste jamais bloqué indéfiniment.
Future<void> _waitImageDecoded(html.ImageElement img) async {
  // Si l'image est déjà complète (cache navigateur), on ne dépend pas de onLoad.
  if (img.complete == true && (img.naturalWidth) > 0) {
    return;
  }

  final completer = Completer<void>();

  late StreamSubscription<html.Event> loadSub;
  late StreamSubscription<html.Event> errorSub;
  Timer? timer;

  void cleanup() {
    loadSub.cancel();
    errorSub.cancel();
    timer?.cancel();
  }

  loadSub = img.onLoad.listen((_) {
    if (!completer.isCompleted) {
      cleanup();
      completer.complete();
    }
  });
  errorSub = img.onError.listen((_) {
    if (!completer.isCompleted) {
      cleanup();
      completer.completeError(
        StateError('Conversion WebP: échec de chargement de l\'image'),
      );
    }
  });
  timer = Timer(_stepTimeout, () {
    // Certains navigateurs décodent sans émettre onLoad: on tente une dernière
    // vérification avant d'abandonner.
    if (!completer.isCompleted) {
      cleanup();
      if ((img.naturalWidth) > 0) {
        completer.complete();
      } else {
        completer.completeError(
          StateError('Conversion WebP: délai de décodage dépassé'),
        );
      }
    }
  });

  return completer.future;
}

Future<html.Blob?> _canvasToBlob(
  html.CanvasElement canvas,
  String type,
  double quality,
) async {
  return canvas.toBlob(type, quality).timeout(
        _stepTimeout,
        onTimeout: () =>
            throw StateError('Conversion WebP: toBlob délai dépassé'),
      );
}

Future<Uint8List> _blobToBytes(html.Blob blob) async {
  final reader = html.FileReader();
  final completer = Completer<Uint8List>();

  reader.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Conversion WebP: FileReader error'));
    }
  });

  reader.onLoadEnd.first.then((_) {
    if (completer.isCompleted) return;
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
    } else {
      completer.completeError(StateError('Conversion WebP: result invalide'));
    }
  });

  reader.readAsArrayBuffer(blob);
  return completer.future.timeout(
    _stepTimeout,
    onTimeout: () =>
        throw StateError('Conversion WebP: lecture du blob délai dépassé'),
  );
}
