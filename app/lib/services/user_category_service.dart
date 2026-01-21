import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_category_model.dart';

/// Service pour gérer les catégories d'utilisateurs
class UserCategoryService {
  static final UserCategoryService _instance = UserCategoryService._internal();
  factory UserCategoryService() => _instance;
  UserCategoryService._internal();

  static UserCategoryService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Récupérer toutes les définitions de catégories
  Stream<List<UserCategoryDefinition>> getCategoriesStream() {
    return _firestore
        .collection('userCategories')
        .where('isActive', isEqualTo: true)
        .orderBy('priority')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserCategoryDefinition.fromFirestore(doc))
            .toList());
  }

  /// Récupérer une catégorie spécifique
  Future<UserCategoryDefinition?> getCategory(String categoryId) async {
    try {
      final doc =
          await _firestore.collection('userCategories').doc(categoryId).get();
      if (!doc.exists) return null;
      return UserCategoryDefinition.fromFirestore(doc);
    } catch (e) {
      print('Erreur lors de la récupération de la catégorie: $e');
      return null;
    }
  }

  /// Récupérer les catégories d'un utilisateur
  Stream<List<UserCategoryAssignment>> getUserCategoriesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserCategoryAssignment.fromMap(doc.data()))
            .where((assignment) => assignment.isValid)
            .toList());
  }

  /// Initialiser les catégories par défaut (admin uniquement)
  Future<Map<String, dynamic>> initializeCategories() async {
    try {
      final callable = _functions.httpsCallable('initializeUserCategories');
      final result = await callable.call();
      return result.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
          'Erreur lors de l\'initialisation des catégories: ${e.toString()}');
    }
  }

  /// Assigner une catégorie à un utilisateur
  Future<Map<String, dynamic>> assignCategory({
    required String targetUserId,
    required String categoryId,
    DateTime? expiresAt,
    String? verificationProof,
  }) async {
    try {
      final callable = _functions.httpsCallable('assignUserCategory');
      final result = await callable.call({
        'targetUserId': targetUserId,
        'categoryId': categoryId,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        if (verificationProof != null) 'verificationProof': verificationProof,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
          'Erreur lors de l\'assignation de la catégorie: ${e.toString()}');
    }
  }

  /// Révoquer une catégorie d'un utilisateur (admin uniquement)
  Future<Map<String, dynamic>> revokeCategory({
    required String targetUserId,
    required String categoryId,
  }) async {
    try {
      final callable = _functions.httpsCallable('revokeUserCategory');
      final result = await callable.call({
        'targetUserId': targetUserId,
        'categoryId': categoryId,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
          'Erreur lors de la révocation de la catégorie: ${e.toString()}');
    }
  }

  /// Vérifier si un utilisateur a une catégorie spécifique
  Future<bool> hasCategory(String userId, String categoryId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(categoryId)
          .get();

      if (!doc.exists) return false;

      final assignment = UserCategoryAssignment.fromMap(doc.data()!);
      return assignment.isValid;
    } catch (e) {
      print('Erreur lors de la vérification de la catégorie: $e');
      return false;
    }
  }

  /// Récupérer les catégories auto-assignables
  Future<List<UserCategoryDefinition>> getSelfAssignableCategories() async {
    try {
      final snapshot = await _firestore
          .collection('userCategories')
          .where('isActive', isEqualTo: true)
          .where('requiresApproval', isEqualTo: false)
          .orderBy('priority')
          .get();

      return snapshot.docs
          .map((doc) => UserCategoryDefinition.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des catégories: $e');
      return [];
    }
  }
}
