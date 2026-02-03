import 'package:cloud_firestore/cloud_firestore.dart';

/// Type de soumission commerce
enum SubmissionType {
  product,
  media;

  String toJson() => name;

  static SubmissionType fromJson(String? value) {
    switch (value) {
      case 'product':
        return SubmissionType.product;
      case 'media':
        return SubmissionType.media;
      default:
        return SubmissionType.product;
    }
  }
}

/// Statut de la soumission
enum SubmissionStatus {
  draft, // Brouillon non soumis
  pending, // En attente de validation
  approved, // Approuvé et publié
  rejected; // Refusé

  String toJson() => name;

  static SubmissionStatus fromJson(String? value) {
    switch (value) {
      case 'draft':
        return SubmissionStatus.draft;
      case 'pending':
        return SubmissionStatus.pending;
      case 'approved':
        return SubmissionStatus.approved;
      case 'rejected':
        return SubmissionStatus.rejected;
      default:
        return SubmissionStatus.draft;
    }
  }
}

/// Rôle du propriétaire
enum OwnerRole {
  adminGroupe,
  createurDigital,
  comptePro,
  superadmin;

  String toJson() {
    switch (this) {
      case OwnerRole.adminGroupe:
        return 'admin_groupe';
      case OwnerRole.createurDigital:
        return 'createur_digital';
      case OwnerRole.comptePro:
        return 'compte_pro';
      case OwnerRole.superadmin:
        return 'superadmin';
    }
  }

  static OwnerRole fromJson(String? value) {
    switch (value) {
      case 'admin_groupe':
        return OwnerRole.adminGroupe;
      case 'createur_digital':
        return OwnerRole.createurDigital;
      case 'compte_pro':
        return OwnerRole.comptePro;
      case 'superadmin':
        return OwnerRole.superadmin;
      default:
        return OwnerRole.comptePro;
    }
  }
}

/// Type de scope (portée)
enum ScopeType {
  group,
  event,
  circuit,
  global;

  String toJson() => name;

  static ScopeType fromJson(String? value) {
    switch (value) {
      case 'group':
        return ScopeType.group;
      case 'event':
        return ScopeType.event;
      case 'circuit':
        return ScopeType.circuit;
      case 'global':
        return ScopeType.global;
      default:
        return ScopeType.global;
    }
  }
}

/// Type de média
enum MediaType {
  photo,
  video;

  String toJson() => name;

  static MediaType fromJson(String? value) {
    switch (value) {
      case 'photo':
        return MediaType.photo;
      case 'video':
        return MediaType.video;
      default:
        return MediaType.photo;
    }
  }
}

/// Modèle de soumission commerce (produit ou média)
class CommerceSubmission {
  final String id;
  final SubmissionType type;
  final SubmissionStatus status;
  final String ownerUid;
  final OwnerRole ownerRole;
  final ScopeType scopeType;
  final String scopeId;
  final String title;
  final String description;
  final List<String> mediaUrls;
  final String? thumbUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final String? moderatedBy;
  final DateTime? moderatedAt;
  final String? moderationNote;
  final String? publishedRef;

  // Champs produit (si type="product")
  final double? price;
  final String? currency;
  final int? stock;
  final bool? isActive;

  // Champs media (si type="media")
  final MediaType? mediaType;
  final DateTime? takenAt;
  final GeoPoint? location;
  final String? photographer;

  CommerceSubmission({
    required this.id,
    required this.type,
    required this.status,
    required this.ownerUid,
    required this.ownerRole,
    required this.scopeType,
    required this.scopeId,
    required this.title,
    required this.description,
    required this.mediaUrls,
    this.thumbUrl,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
    this.moderatedBy,
    this.moderatedAt,
    this.moderationNote,
    this.publishedRef,
    this.price,
    this.currency,
    this.stock,
    this.isActive,
    this.mediaType,
    this.takenAt,
    this.location,
    this.photographer,
  });

  /// Helpers
  bool get isProduct => type == SubmissionType.product;
  bool get isMedia => type == SubmissionType.media;
  bool get isDraft => status == SubmissionStatus.draft;
  bool get isPending => status == SubmissionStatus.pending;
  bool get isApproved => status == SubmissionStatus.approved;
  bool get isRejected => status == SubmissionStatus.rejected;
  bool get canEdit => isDraft || isRejected;
  bool get canSubmit => isDraft || isRejected;
  bool get canModerate => isPending;

  /// Créer depuis Firestore
  factory CommerceSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommerceSubmission.fromMap(doc.id, data);
  }

  /// Créer depuis Map
  factory CommerceSubmission.fromMap(String id, Map<String, dynamic> data) {
    return CommerceSubmission(
      id: id,
      type: SubmissionType.fromJson(data['type'] as String?),
      status: SubmissionStatus.fromJson(data['status'] as String?),
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerRole: OwnerRole.fromJson(data['ownerRole'] as String?),
      scopeType: ScopeType.fromJson(data['scopeType'] as String?),
      scopeId: data['scopeId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      mediaUrls: (data['mediaUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      thumbUrl: data['thumbUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      moderatedBy: data['moderatedBy'] as String?,
      moderatedAt: (data['moderatedAt'] as Timestamp?)?.toDate(),
      moderationNote: data['moderationNote'] as String?,
      publishedRef: data['publishedRef'] as String?,
      price: (data['price'] as num?)?.toDouble(),
      currency: data['currency'] as String?,
      stock: data['stock'] as int?,
      isActive: data['isActive'] as bool?,
      mediaType: data['mediaType'] != null
          ? MediaType.fromJson(data['mediaType'] as String?)
          : null,
      takenAt: (data['takenAt'] as Timestamp?)?.toDate(),
      location: data['location'] as GeoPoint?,
      photographer: data['photographer'] as String?,
    );
  }

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'type': type.toJson(),
      'status': status.toJson(),
      'ownerUid': ownerUid,
      'ownerRole': ownerRole.toJson(),
      'scopeType': scopeType.toJson(),
      'scopeId': scopeId,
      'title': title,
      'description': description,
      'mediaUrls': mediaUrls,
      'thumbUrl': thumbUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'moderatedBy': moderatedBy,
      'moderatedAt': moderatedAt != null ? Timestamp.fromDate(moderatedAt!) : null,
      'moderationNote': moderationNote,
      'publishedRef': publishedRef,
    };

    // Champs produit
    if (isProduct) {
      map['price'] = price;
      map['currency'] = currency;
      map['stock'] = stock;
      map['isActive'] = isActive;
    }

    // Champs media
    if (isMedia) {
      map['mediaType'] = mediaType?.toJson();
      map['takenAt'] = takenAt != null ? Timestamp.fromDate(takenAt!) : null;
      map['location'] = location;
      map['photographer'] = photographer;
    }

    return map;
  }

  /// Copier avec modifications
  CommerceSubmission copyWith({
    String? id,
    SubmissionType? type,
    SubmissionStatus? status,
    String? ownerUid,
    OwnerRole? ownerRole,
    ScopeType? scopeType,
    String? scopeId,
    String? title,
    String? description,
    List<String>? mediaUrls,
    String? thumbUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
    String? moderatedBy,
    DateTime? moderatedAt,
    String? moderationNote,
    String? publishedRef,
    double? price,
    String? currency,
    int? stock,
    bool? isActive,
    MediaType? mediaType,
    DateTime? takenAt,
    GeoPoint? location,
    String? photographer,
  }) {
    return CommerceSubmission(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerRole: ownerRole ?? this.ownerRole,
      scopeType: scopeType ?? this.scopeType,
      scopeId: scopeId ?? this.scopeId,
      title: title ?? this.title,
      description: description ?? this.description,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      moderatedBy: moderatedBy ?? this.moderatedBy,
      moderatedAt: moderatedAt ?? this.moderatedAt,
      moderationNote: moderationNote ?? this.moderationNote,
      publishedRef: publishedRef ?? this.publishedRef,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      mediaType: mediaType ?? this.mediaType,
      takenAt: takenAt ?? this.takenAt,
      location: location ?? this.location,
      photographer: photographer ?? this.photographer,
    );
  }

  @override
  String toString() => 'CommerceSubmission(id: $id, type: $type, status: $status, title: $title)';
}
