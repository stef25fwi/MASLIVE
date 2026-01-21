import 'package:cloud_firestore/cloud_firestore.dart';

/// Type de catégorie utilisateur
enum UserCategoryType {
  pilote,      // Pilote de moto
  passager,    // Passager
  organisateur, // Organisateur d'événements
  comercant,   // Commerçant/Vendeur
  secours,     // Personnel de secours
  vip,         // VIP/Partenaire privilégié
  media,       // Média/Presse
  benevole,    // Bénévole
  spectateur,  // Spectateur
}

/// Extension pour obtenir le libellé de la catégorie
extension UserCategoryTypeExtension on UserCategoryType {
  String get label {
    switch (this) {
      case UserCategoryType.pilote:
        return 'Pilote';
      case UserCategoryType.passager:
        return 'Passager';
      case UserCategoryType.organisateur:
        return 'Organisateur';
      case UserCategoryType.comercant:
        return 'Commerçant';
      case UserCategoryType.secours:
        return 'Secours';
      case UserCategoryType.vip:
        return 'VIP';
      case UserCategoryType.media:
        return 'Média';
      case UserCategoryType.benevole:
        return 'Bénévole';
      case UserCategoryType.spectateur:
        return 'Spectateur';
    }
  }

  String get id {
    return name;
  }
}

/// Avantages associés à une catégorie
class CategoryBenefit {
  final String id;
  final String title;
  final String description;
  final String? iconName;

  CategoryBenefit({
    required this.id,
    required this.title,
    required this.description,
    this.iconName,
  });

  factory CategoryBenefit.fromMap(Map<String, dynamic> map) {
    return CategoryBenefit(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      iconName: map['iconName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      if (iconName != null) 'iconName': iconName,
    };
  }
}

/// Modèle de définition de catégorie utilisateur
class UserCategoryDefinition {
  final String id;
  final String name;
  final String description;
  final UserCategoryType categoryType;
  final List<CategoryBenefit> benefits;
  final int priority; // Pour l'ordre d'affichage
  final bool isActive;
  final bool requiresApproval; // Si la catégorie nécessite une approbation admin
  final String? badgeColor; // Couleur du badge (format hex)
  final String? iconName; // Nom de l'icône Material
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserCategoryDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryType,
    this.benefits = const [],
    required this.priority,
    this.isActive = true,
    this.requiresApproval = false,
    this.badgeColor,
    this.iconName,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserCategoryDefinition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserCategoryDefinition(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      categoryType: _parseCategory(data['categoryType']),
      benefits: (data['benefits'] as List<dynamic>?)
          ?.map((b) => CategoryBenefit.fromMap(b as Map<String, dynamic>))
          .toList() ?? [],
      priority: data['priority'] ?? 0,
      isActive: data['isActive'] ?? true,
      requiresApproval: data['requiresApproval'] ?? false,
      badgeColor: data['badgeColor'],
      iconName: data['iconName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'categoryType': categoryType.name,
      'benefits': benefits.map((b) => b.toMap()).toList(),
      'priority': priority,
      'isActive': isActive,
      'requiresApproval': requiresApproval,
      if (badgeColor != null) 'badgeColor': badgeColor,
      if (iconName != null) 'iconName': iconName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static UserCategoryType _parseCategory(dynamic value) {
    if (value == null) return UserCategoryType.spectateur;
    final str = value.toString().toLowerCase();
    
    try {
      return UserCategoryType.values.firstWhere(
        (type) => type.name == str,
        orElse: () => UserCategoryType.spectateur,
      );
    } catch (e) {
      return UserCategoryType.spectateur;
    }
  }

  /// Vérifie si l'utilisateur peut s'auto-assigner cette catégorie
  bool get canSelfAssign => !requiresApproval;
}

/// Catégorie assignée à un utilisateur spécifique
class UserCategoryAssignment {
  final String userId;
  final String categoryId;
  final UserCategoryType categoryType;
  final DateTime assignedAt;
  final DateTime? expiresAt;
  final String? assignedBy; // UID de l'admin qui a assigné (si applicable)
  final String? verificationProof; // URL ou référence vers preuve de vérification
  final bool isActive;

  UserCategoryAssignment({
    required this.userId,
    required this.categoryId,
    required this.categoryType,
    required this.assignedAt,
    this.expiresAt,
    this.assignedBy,
    this.verificationProof,
    this.isActive = true,
  });

  factory UserCategoryAssignment.fromMap(Map<String, dynamic> map) {
    return UserCategoryAssignment(
      userId: map['userId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      categoryType: UserCategoryDefinition._parseCategory(map['categoryType']),
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      assignedBy: map['assignedBy'],
      verificationProof: map['verificationProof'],
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'categoryId': categoryId,
      'categoryType': categoryType.name,
      'assignedAt': Timestamp.fromDate(assignedAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (assignedBy != null) 'assignedBy': assignedBy,
      if (verificationProof != null) 'verificationProof': verificationProof,
      'isActive': isActive,
    };
  }

  /// Vérifie si la catégorie est encore valide
  bool get isValid {
    if (!isActive) return false;
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }
}
