import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

enum HomeControlsThemeMode { classic, ultraPremiumGlass }

class HomeControlsThemeService {
  HomeControlsThemeService({
    FirebaseFirestore? firestore,
    bool waitForFirebaseInitialization = true,
  }) : _firestore = firestore,
       _waitForFirebaseInitialization = waitForFirebaseInitialization;

  static const String configCollection = 'config';
  static const String systemDocument = 'system';
  static const String fieldName = 'homeControlsTheme';

  final FirebaseFirestore? _firestore;
  final bool _waitForFirebaseInitialization;

  Stream<HomeControlsThemeMode> watchTheme() async* {
    yield HomeControlsThemeMode.classic;

    final firestore = await _waitForFirestore();
    if (firestore == null) {
      return;
    }

    yield* firestore
        .collection(configCollection)
        .doc(systemDocument)
        .snapshots()
        .map((snapshot) => fromConfig(snapshot.data()))
        .distinct();
  }

  Future<void> saveTheme(HomeControlsThemeMode theme) {
    final firestore = _resolveFirestoreOrThrow();
    return firestore.collection(configCollection).doc(systemDocument).set({
      fieldName: toStorage(theme),
    }, SetOptions(merge: true));
  }

  Future<FirebaseFirestore?> _waitForFirestore() async {
    if (_firestore != null) {
      return _firestore;
    }
    if (Firebase.apps.isNotEmpty) {
      return FirebaseFirestore.instance;
    }
    if (!_waitForFirebaseInitialization) {
      return null;
    }

    const deadline = Duration(seconds: 8);
    const step = Duration(milliseconds: 250);
    final stopwatch = Stopwatch()..start();
    while (Firebase.apps.isEmpty && stopwatch.elapsed < deadline) {
      await Future<void>.delayed(step);
    }

    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseFirestore.instance;
  }

  FirebaseFirestore _resolveFirestoreOrThrow() {
    final firestore = _firestore;
    if (firestore != null) {
      return firestore;
    }
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase n\'est pas initialisé');
    }
    return FirebaseFirestore.instance;
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
