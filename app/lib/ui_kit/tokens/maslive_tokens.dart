import 'package:flutter/material.dart';

/// Design tokens MASLIVE — SOURCE UNIQUE de vérité pour couleurs, rayons et
/// espacements dans toute l'app (wizard, admin, glass, POI, checkout...).
///
/// `MasliveTheme` (ui/theme/maslive_theme.dart) construit le `ThemeData`
/// Material de l'app à partir de CES tokens : ne pas dupliquer une valeur
/// ailleurs, référencer ce fichier.
///
/// Historique : avant cette unification, `MasliveTokens` et `MasliveTheme`
/// définissaient chacun leur propre échelle de couleurs/rayons avec des
/// valeurs différentes (deux "noirs" de texte, deux échelles de rayon...).
/// Voir AUDIT_VISUEL — l'écart est documenté et ces valeurs sont désormais
/// la référence commune.
class MasliveTokens {
  // ---------- Neutres (encre) ----------
  /// Texte principal / encre la plus foncée.
  static const Color text = Color(0xFF16181F);

  /// Texte secondaire (labels, sous-titres, icônes inactives).
  static const Color textMuted = Color(0xFF5A6272);

  /// Texte tertiaire / placeholder / valeurs peu importantes.
  static const Color textFaint = Color(0xFF8B93A3);

  /// Version translucide de [text], pour superposition sur fond variable.
  /// Préférer [textMuted] (couleur plate) quand le fond est connu.
  static Color get textSoft => text.withValues(alpha: 0.55);

  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Colors.white;

  /// Ligne de séparation / bordure neutre plate (cartes, inputs, listes).
  static const Color line = Color(0xFFE6E9F0);

  static Color get borderSoft => Colors.black.withValues(alpha: 0.07);
  static Color get shadow => Colors.black.withValues(alpha: 0.06);

  /// Blanc "glass". L'opacité finale est contrôlée par les widgets glass.
  static Color get glass => Colors.white.withValues(alpha: 0.76);

  // ---------- Marque ----------
  /// Accent unique (liens, focus, sélection, CTA secondaires). Le dégradé
  /// signature pastel (jaune→rose→violet→bleu) reste réservé aux en-têtes
  /// et FAB de marque — voir `MasliveTheme.headerGradient`.
  static const Color primary = Color(0xFF8B5CF6);

  // ---------- Sémantique (distincte de l'accent) ----------
  static const Color success = Color(0xFF159A5B);
  static const Color warning = Color(0xFFC9820B);
  static const Color danger = Color(0xFFD63A3A);

  // ---------- Radius ----------
  static const double rS = 10;
  static const double rM = 14;
  static const double rL = 20;
  static const double rXL = 28;
  static const double rPill = 999;

  // ---------- Spacing ----------
  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}
