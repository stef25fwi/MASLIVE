import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service pour vérifier les permissions utilisateur pour upload/édition de médias
class MediaPermissionsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Vérifie si l'utilisateur connecté peut uploader des médias
  /// Retourne true si:
  /// - Super admin (email hardcodé s-stephane@live.fr) OU
  /// - Compte pro avec activité "createur_digital" en Firestore
  static Future<bool> canUploadMedia() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Super admin hardcodé (fallback)
    if (user.email == 's-stephane@live.fr') return true;

    // Vérifier dans Firestore users/<uid>
    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data();
      final accountType = data?['accountType'] as String?;
      final activities = data?['activities'] as List?;

      // Compte pro + activité "createur_digital"
      if (accountType == 'pro' && activities != null) {
        return activities.contains('createur_digital');
      }

      return false;
    } catch (e) {
      // En cas d'erreur Firestore, refuser l'accès
      return false;
    }
  }

  /// Récupère le nom du photographe depuis Firestore pour les uploads
  static Future<String> getPhotographerName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Photographe';

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return user.displayName ?? 'Photographe';

      final data = userDoc.data();
      final name = data?['displayName'] as String?;
      return name?.trim().isEmpty == false
          ? name!
          : (user.displayName ?? 'Photographe');
    } catch (e) {
      return user.displayName ?? 'Photographe';
    }
  }
}
