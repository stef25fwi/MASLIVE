// lib/ui/theme/maslive_theme.dart
//
// MASLIVE Premium Pastel Theme (mockup style)
// - White glass background + subtle honeycomb overlay
// - Pastel gradient headers (yellow → pink → violet → blue)
// - Soft shadows, rounded cards, pill chips, gradient FAB
//
// Usage:
//   import 'package:your_app/ui/theme/maslive_theme.dart';
//
//   MaterialApp(
//     theme: MasliveTheme.lightTheme,
//     home: const HomeMapPage(),
//   );
//
// Optional helper widgets are included at bottom:
//   - MasliveCard
//   - MaslivePill
//   - MasliveGradientIconButton
//   - MasliveBottomNav (simple)
//   - MasliveFab
//
// If you want GoogleFonts, add google_fonts and swap TextTheme builder.

import 'package:flutter/material.dart';

class MasliveTheme {
  MasliveTheme._();

  // ---------- Core colors ----------
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF6F7FB);

  static const Color textPrimary = Color(0xFF1D2330);
  static const Color textSecondary = Color(0xFF6E7787);

  static const Color pink = Color(0xFFFF6BB5);

  static const Color divider = Color(0xFFE9EDF5);

  // ---------- Gradients (mockup pastel) ----------
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFE66D), // soft yellow
      Color(0xFFFF6BB5), // pink
      Color(0xFFB66CFF), // violet
      Color(0xFF57C7FF), // sky blue
    ],
    stops: [0.00, 0.35, 0.68, 1.00],
  );

  static const LinearGradient actionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFCC6A), // warm yellow
      Color(0xFFFF6BB5), // pink
      Color(0xFFA56BFF), // violet
    ],
    stops: [0.00, 0.55, 1.00],
  );

  // Optional subtle background tint gradient (behind everything)
  static const LinearGradient backgroundWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFDFDFF),
      Color(0xFFF6F7FB),
    ],
  );

  // ---------- Radius ----------
  static const double rHeader = 28.0;
  static const double rCard = 20.0;
  static const double rTile = 16.0;
  static const double rPill = 999.0;

  // ---------- Spacing ----------
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;

  // ---------- Shadows ----------
  // Soft card shadow like the mockup
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x14000000), // ~8% opacity
      blurRadius: 18,
      offset: Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color(0x24000000), // ~14% opacity
      blurRadius: 22,
      offset: Offset(0, 12),
      spreadRadius: 0,
    ),
  ];

  // Premium border with elegant white outline and soft shadow
  static const List<BoxShadow> premiumBorderShadow = [
    BoxShadow(
      color: Color(0x2E000000), // ~18% opacity
      blurRadius: 18,
      offset: Offset(0, 10),
    ),
  ];

  static const Border premiumBorder = Border(
    top: BorderSide(color: Color(0xFFFFFFFF), width: 2),
    bottom: BorderSide(color: Color(0xFFFFFFFF), width: 2),
    left: BorderSide(color: Color(0xFFFFFFFF), width: 2),
    right: BorderSide(color: Color(0xFFFFFFFF), width: 2),
  );

  // Internal bevel border for beveled edge effect
  static const Border bevelBorder = Border(
    top: BorderSide(color: Color(0x1A000000), width: 1),
    bottom: BorderSide(color: Color(0x1A000000), width: 1),
    left: BorderSide(color: Color(0x1A000000), width: 1),
    right: BorderSide(color: Color(0x1A000000), width: 1),
  );

  // Complete premium decoration with white border + shadow
  static BoxDecoration get premiumDecoration {
    return BoxDecoration(
      border: premiumBorder,
      boxShadow: premiumBorderShadow,
      borderRadius: BorderRadius.circular(rCard),
    );
  }

  // Internal bevel decoration (overlay on top for beveled effect)
  static BoxDecoration get bevelDecoration {
    return BoxDecoration(
      border: bevelBorder,
      borderRadius: BorderRadius.circular(rCard),
    );
  }

  // Premium + Bevel combination
  static BoxDecoration get premiumWithBevelDecoration {
    return BoxDecoration(
      border: premiumBorder,
      boxShadow: premiumBorderShadow,
      borderRadius: BorderRadius.circular(rCard),
    );
  }

  // ---------- ThemeData ----------
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6BB5),
        brightness: Brightness.light,
        surface: surface,
      ).copyWith(
        surface: surface,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      dividerColor: divider,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        centerTitle: true,
      ),

      textTheme: _textTheme(base.textTheme),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rCard),
        ),
      ),

      listTileTheme: ListTileThemeData(
        dense: false,
        iconColor: textSecondary,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rTile),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: s16,
          vertical: 2,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          color: textSecondary,
        ),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: s16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rPill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rPill),
          borderSide: BorderSide(
            color: divider,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rPill),
          borderSide: BorderSide(
            color: const Color(0x33FF6BB5),
            width: 1.2,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: const Color(0x14FF6BB5),
        disabledColor: divider,
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: StadiumBorder(
          side: BorderSide(color: divider),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        selectedItemColor: textPrimary,
        unselectedItemColor: textSecondary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme t) {
    // Clean iOS-like typography (no dependency)
    return t.copyWith(
      headlineLarge: t.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.2,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.2,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      bodyLarge: t.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.25,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.25,
      ),
      bodySmall: t.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        height: 1.25,
      ),
      labelLarge: t.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      labelMedium: t.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
    );
  }
}

// NOTE: Les widgets du design system sont dans lib/ui/widgets/.
