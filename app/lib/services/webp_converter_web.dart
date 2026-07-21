// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

const bool supportsWebpConversion = true;

Future<Uint8List> convertBytesToWebp(
  Uint8List bytes, {
  int quality = 88,
}) async {
  final q = quality.clamp(0, 100) / 100.0;

  final blob = html.Blob(<dynamic>[bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  try {
    final img = html.ImageElement(src: url);
    // Certains formats (HEIC/HEIF des photos iPhone, images corrompues) ne
    // peuvent pas être décodés par le <img> du navigateur : celui-ci émet
    // alors 'error' au lieu de 'load'. Sans écouter 'error' ni borner
    // l'attente, cette future ne se termine jamais et bloque tout l'upload.
    // On échoue vite (timeout inclus) pour laisser l'appelant retomber sur
    // les octets d'origine.
    bool loaded = false;
    await Future.any<void>([
      img.onLoad.first.then((_) => loaded = true),
      img.onError.first.then((_) {}),
      Future<void>.delayed(const Duration(seconds: 5)),
    ]);
    if (!loaded) {
      throw StateError(
        'Impossible de charger l\'image pour conversion WebP (format non supporté par le navigateur)',
      );
    }

    final width = img.naturalWidth;
    final height = img.naturalHeight;

    if (width <= 0 || height <= 0) {
      throw StateError('Image invalide (dimensions nulles)');
    }

    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;
    ctx.drawImage(img, 0, 0);

    final webpBlob = await _canvasToBlob(canvas, 'image/webp', q);
    final webpBytes = await _blobToBytes(webpBlob);
    return webpBytes;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

Future<html.Blob> _canvasToBlob(
  html.CanvasElement canvas,
  String type,
  double quality,
) async {
  return canvas.toBlob(type, quality);
}

Future<Uint8List> _blobToBytes(html.Blob blob) async {
  final reader = html.FileReader();
  final completer = Completer<Uint8List>();

  reader.onError.first.then((_) {
    completer.completeError(StateError('Conversion WebP: FileReader error'));
  });

  reader.onLoadEnd.first.then((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
    } else {
      completer.completeError(StateError('Conversion WebP: result invalide'));
    }
  });

  reader.readAsArrayBuffer(blob);
  return completer.future;
}
