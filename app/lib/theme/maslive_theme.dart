import 'package:flutter/material.dart';

class MasLiveTheme {
  static ThemeData light() {
    const primary = Color(0xFFFF6600); // orange
    const secondary = Color(0xFF1A73E8); // bleu

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.white,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
  
  // Couleurs de rôles pour compatibilité avec les fichiers existants
  static const Color roleUser = Color(0xFF4CAF50);
  static const Color roleTracker = Color(0xFF2196F3);
  static const Color roleGroup = Color(0xFFFF9800);
  static const Color roleAdmin = Color(0xFFF44336);
  static const Color roleSuperAdmin = Color(0xFF9C27B0);
  
  static Color getRoleColor(dynamic role) {
    final roleStr = role.toString().split('.').last;
    switch (roleStr) {
      case 'user':
        return roleUser;
      case 'tracker':
        return roleTracker;
      case 'group':
        return roleGroup;
      case 'admin':
        return roleAdmin;
      case 'superAdmin':
        return roleSuperAdmin;
      default:
        return roleUser;
    }
  }
  
  static IconData getRoleIcon(dynamic role) {
    final roleStr = role.toString().split('.').last;
    switch (roleStr) {
      case 'user':
        return Icons.person;
      case 'tracker':
        return Icons.location_on;
      case 'group':
        return Icons.group;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'superAdmin':
        return Icons.shield;
      default:
        return Icons.person;
    }
  }
  
  /// Thème clair (ancien)
  static ThemeData get lightTheme {
    return light();
  }
  
  /// Thème sombre (ancien)
  static ThemeData get darkTheme {
    return light(); // Pas de dark mode pour l'instant
  }
}
