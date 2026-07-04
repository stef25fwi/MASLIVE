// Lecture de la position moyenne d'un groupe.
//
// Le CALCUL de la moyenne (centroïde géodésique pondéré + rejet d'outliers) est
// désormais assuré côté serveur par la Cloud Function `calculateGroupAveragePosition`
// (functions/group_tracking.js), déclenchée sur group_positions/{adminGroupId}/members.
// Ce service ne fait plus que LIRE le résultat publié dans group_admins.averagePosition.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_admin.dart';

class GroupAverageService {
  static final GroupAverageService instance = GroupAverageService._();
  GroupAverageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream de la position moyenne du groupe (calculée et publiée par la
  /// Cloud Function). Retourne `null` si aucun admin/position n'est disponible.
  Stream<GeoPosition?> streamAveragePosition(String adminGroupId) {
    return _firestore
        .collection('group_admins')
        .where('adminGroupId', isEqualTo: adminGroupId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final admin = GroupAdmin.fromFirestore(snapshot.docs.first);
      return admin.averagePosition;
    });
  }
}
