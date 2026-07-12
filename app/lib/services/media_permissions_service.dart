import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service pour vérifier les permissions utilisateur pour upload/édition de médias.
class MediaPermissionsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Vérifie si l'utilisateur connecté peut uploader des médias.
  /// Retourne true si :
  /// - super admin fallback ;
  /// - activité `createur_digital` / `creator_digital` dans `users/{uid}` ;
  /// - profil photographe existant, exposé côté app comme Créateur digital.
  static Future<bool> canUploadMedia() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Super admin hardcodé (fallback historique).
    if (user.email == 's-stephane@live.fr') return true;

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final activities = (userData['activities'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toSet() ??
          const <String>{};

      if (activities.contains('createur_digital') ||
          activities.contains('creator_digital')) {
        return true;
      }

      final photographerSnap = await _db
          .collection('photographers')
          .where('ownerUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      return photographerSnap.docs.isNotEmpty;
    } catch (_) {
      // En cas d'erreur Firestore, refuser l'accès.
      return false;
    }
  }

  /// Récupère le nom du créateur depuis Firestore pour les uploads.
  static Future<String> getPhotographerName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Créateur digital';

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return user.displayName ?? 'Créateur digital';

      final data = userDoc.data();
      final name = data?['displayName'] as String?;
      return name?.trim().isEmpty == false
          ? name!
          : (user.displayName ?? 'Créateur digital');
    } catch (_) {
      return user.displayName ?? 'Créateur digital';
    }
  }
}
