import 'package:cloud_firestore/cloud_firestore.dart';

enum HomeControlsThemeMode { classic, ultraPremiumGlass }

class HomeControlsThemeService {
  HomeControlsThemeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String configCollection = 'config';
  static const String systemDocument = 'system';
  static const String fieldName = 'homeControlsTheme';

  final FirebaseFirestore _firestore;

  Stream<HomeControlsThemeMode> watchTheme() {
    return _firestore
        .collection(configCollection)
        .doc(systemDocument)
        .snapshots()
        .map((snapshot) => fromConfig(snapshot.data()))
        .distinct();
  }

  Future<void> saveTheme(HomeControlsThemeMode theme) {
    return _firestore.collection(configCollection).doc(systemDocument).set({
      fieldName: toStorage(theme),
    }, SetOptions(merge: true));
  }

  static HomeControlsThemeMode fromConfig(Map<String, dynamic>? config) {
    final raw = (config?[fieldName] ?? '').toString().trim();
    switch (raw) {
      case 'ultraPremiumGlass':
      case 'ultra_premium_glass':
      case 'glass':
      case 'premium':
        return HomeControlsThemeMode.ultraPremiumGlass;
      case 'classic':
      default:
        return HomeControlsThemeMode.classic;
    }
  }

  static String toStorage(HomeControlsThemeMode theme) {
    switch (theme) {
      case HomeControlsThemeMode.ultraPremiumGlass:
        return 'ultraPremiumGlass';
      case HomeControlsThemeMode.classic:
        return 'classic';
    }
  }
}
