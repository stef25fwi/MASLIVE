import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'maslive_poi_style.dart';

/// Préfixe des identifiants d'images Mapbox pour les pictos POI.
const String kPoiPictoImagePrefix = 'maslive_picto_';

/// Identifiant d'image Mapbox pour un picto donné (ex: `maslive_picto_food`).
String poiPictoImageId(String pictoId) => '$kPoiPictoImagePrefix$pictoId';

/// Propriété GeoJSON portant l'identifiant d'image picto d'un POI.
const String kPoiPictoIconIdProperty = 'pictoIconId';

/// Une image de picto pré-rasterisée, prête à être enregistrée sur la carte.
///
/// Rasterisée une fois côté Dart (avec la vraie police Material), puis fournie
/// aux moteurs de rendu :
/// - Web (Mapbox GL JS) : via [png] (créé un `ImageElement` puis `addImage`).
/// - Natif (mapbox_maps_flutter) : via [rgba] (`MbxImage` + `addStyleImage`).
class PoiPictoImage {
  final String id;
  final String pictoId;
  final int width;
  final int height;
  final Uint8List rgba;
  final Uint8List png;

  const PoiPictoImage({
    required this.id,
    required this.pictoId,
    required this.width,
    required this.height,
    required this.rgba,
    required this.png,
  });
}

/// Fabrique (avec cache) des images de pictos POI.
///
/// Chaque picto est rendu comme un petit marqueur : disque blanc + anneau
/// coloré + glyphe Material coloré au centre. Le rendu échoue silencieusement
/// pour un picto donné (il est simplement omis) : le POI retombe alors sur son
/// rendu par cercle habituel — aucune régression.
class PoiPictoImageFactory {
  PoiPictoImageFactory._();

  static List<PoiPictoImage>? _cache;
  static double _cacheDpr = 0;

  /// Construit (ou retourne depuis le cache) toutes les images de [kMasLivePoiPictos].
  static Future<List<PoiPictoImage>> build({
    double devicePixelRatio = 2.0,
    double logicalSize = 30.0,
  }) async {
    final dpr = devicePixelRatio.clamp(1.0, 4.0).toDouble();
    final cached = _cache;
    if (cached != null && _cacheDpr == dpr) return cached;

    final out = <PoiPictoImage>[];
    for (final picto in kMasLivePoiPictos) {
      final image = await _renderOne(picto, dpr, logicalSize);
      if (image != null) out.add(image);
    }

    _cache = out;
    _cacheDpr = dpr;
    return out;
  }

  static Future<PoiPictoImage?> _renderOne(
    MasLivePoiPicto picto,
    double dpr,
    double logicalSize,
  ) async {
    try {
      final size = (logicalSize * dpr).round();
      final s = size.toDouble();
      final center = Offset(s / 2, s / 2);
      final radius = s / 2;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Ombre douce sous le marqueur.
      canvas.drawCircle(
        center.translate(0, dpr * 0.6),
        radius - dpr * 1.0,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, dpr * 1.2),
      );

      // Disque blanc.
      canvas.drawCircle(
        center,
        radius - dpr * 1.4,
        Paint()
          ..color = Colors.white
          ..isAntiAlias = true,
      );

      // Anneau coloré.
      canvas.drawCircle(
        center,
        radius - dpr * 1.9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dpr * 1.5
          ..color = picto.color
          ..isAntiAlias = true,
      );

      // Glyphe centré : peintre vectoriel personnalisé si présent (aucune
      // icône Material ne correspond visuellement), sinon glyphe Material.
      final glyphBuilder = picto.painterBuilder;
      if (glyphBuilder != null) {
        final glyphSize = s * 0.62;
        canvas.save();
        canvas.translate(
          center.dx - glyphSize / 2,
          center.dy - glyphSize / 2,
        );
        glyphBuilder(picto.color).paint(canvas, Size(glyphSize, glyphSize));
        canvas.restore();
      } else {
        final glyphSize = s * 0.54;
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(picto.icon.codePoint),
            style: TextStyle(
              fontSize: glyphSize,
              fontFamily: picto.icon.fontFamily,
              package: picto.icon.fontPackage,
              color: picto.color,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
        );
      }

      final image = await recorder.endRecording().toImage(size, size);
      try {
        // Web n'utilise que le PNG, natif que le RGBA : on tolère l'échec de
        // l'un pour ne pas perdre l'autre.
        Uint8List rgba = Uint8List(0);
        Uint8List png = Uint8List(0);
        try {
          final rgbaData = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (rgbaData != null) rgba = rgbaData.buffer.asUint8List();
        } catch (_) {
          // ignore
        }
        try {
          final pngData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (pngData != null) png = pngData.buffer.asUint8List();
        } catch (_) {
          // ignore
        }
        if (rgba.isEmpty && png.isEmpty) return null;
        return PoiPictoImage(
          id: poiPictoImageId(picto.id),
          pictoId: picto.id,
          width: size,
          height: size,
          rgba: rgba,
          png: png,
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}
