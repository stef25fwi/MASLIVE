import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/product_model.dart';

class GroupRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Group> watchGroup(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return Group.fromMap(doc.id, data);
    });
  }

  Stream<List<GroupProduct>> watchProducts(String groupId, {String? category}) {
    return watchProductsWithPending(groupId, category: category, includePending: false);
  }

  Stream<List<GroupProduct>> watchProductsWithPending(
    String groupId, {
    String? category,
    required bool includePending,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('groups')
        .doc(groupId)
        .collection('products')
        .where('isActive', isEqualTo: true);

    if (includePending) {
      q = _db
          .collection('groups')
          .doc(groupId)
          .collection('products');
    }

    if (category != null && category.isNotEmpty) {
      q = q.where('category', isEqualTo: category);
    }

    return q.snapshots().map((snap) {
      return snap.docs
          .map((d) => GroupProduct.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) {
          int rank(GroupProduct p) {
            if (p.isApproved) return 0;
            if (p.isPending) return 1;
            if (p.isRejected) return 2;
            return 3;
          }

          final ar = rank(a);
          final br = rank(b);
          if (ar != br) return ar - br;
          return a.title.compareTo(b.title);
        });
    });
  }

  // ✅ Récupérer tous les groupes actifs
  Stream<List<Group>> watchAllGroups() {
    return _db.collection('groups').snapshots().map((snap) {
      return snap.docs.map((d) => Group.fromMap(d.id, d.data())).toList();
    });
  }

  // ✅ Créer ou mettre à jour un groupe
  Future<void> saveGroup(String groupId, Group group) async {
    await _db.collection('groups').doc(groupId).set(group.toFirestore());
  }

  // ✅ Créer ou mettre à jour un produit
  Future<void> saveProduct(String groupId, String productId, GroupProduct product) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('products')
        .doc(productId)
        .set(product.toFirestore());
  }

  // ✅ Supprimer un produit
  Future<void> deleteProduct(String groupId, String productId) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('products')
        .doc(productId)
        .delete();
  }
}
