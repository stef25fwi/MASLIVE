import 'package:flutter/material.dart';

@immutable
class MasLivePoiStyle {
  final double circleRadius;
  final Color circleColor;
  final double circleStrokeWidth;
  final Color circleStrokeColor;

  const MasLivePoiStyle({
    this.circleRadius = 7.0,
    this.circleColor = const Color(0xFF0A84FF),
    this.circleStrokeWidth = 2.0,
    this.circleStrokeColor = const Color(0xFFFFFFFF),
  });
}

String masLiveColorToCssHex(Color color) {
  int to8(double v) => (v * 255.0).round().clamp(0, 255);

  final r = to8(color.r).toRadixString(16).padLeft(2, '0');
  final g = to8(color.g).toRadixString(16).padLeft(2, '0');
  final b = to8(color.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}
