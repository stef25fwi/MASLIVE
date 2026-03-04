import 'package:flutter/material.dart';

/// Design tokens MASLIVE (Wizard Circuit Pro).
///
/// Objectif: centraliser couleurs, radius, spacing, blur.
/// Strictement visuel.
class MasliveTokens {
  // Colors
  static const Color bg = Color(0xFFF6F7FB);
  static const Color primary = Color(0xFF0A84FF);
  static const Color success = Color(0xFF34C759);
  static const Color text = Color(0xFF0B0F1A);

  static Color get textSoft => text.withValues(alpha: 0.55);
  static Color get borderSoft => Colors.black.withValues(alpha: 0.07);
  static Color get shadow => Colors.black.withValues(alpha: 0.06);

  /// Blanc "glass". L'opacité finale est contrôlée par les widgets glass.
  static Color get glass => Colors.white.withValues(alpha: 0.76);

  // Radius
  static const double rS = 14;
  static const double rM = 18;
  static const double rL = 22;
  static const double rXL = 30;
  static const double rPill = 999;

  // Spacing
  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}
