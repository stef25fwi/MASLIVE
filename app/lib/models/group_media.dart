// Modèle Média Groupe
// Collection: group_shops/{adminGroupId}/media/{mediaId}

import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMedia {
  final String id;
  final String adminGroupId;
  final String url;
  final String type; // "image" ou "video"
  final String? title;
  final Map<String, dynamic> tags; // {country, event, circuit, date, location, photographer}
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupMedia({
    required this.id,
    required this.adminGroupId,
    required this.url,
    required this.type,
    this.title,
    required this.tags,
    this.isVisible = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';

  factory GroupMedia.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupMedia(
      id: doc.id,
      adminGroupId: data['adminGroupId'] ?? '',
      url: data['url'] ?? '',
      type: data['type'] ?? 'image',
      title: data['title'],
      tags: Map<String, dynamic>.from(data['tags'] ?? {}),
      isVisible: data['isVisible'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminGroupId': adminGroupId,
      'url': url,
      'type': type,
      'title': title,
      'tags': tags,
      'isVisible': isVisible,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  GroupMedia copyWith({
    String? url,
    String? type,
    String? title,
    Map<String, dynamic>? tags,
    bool? isVisible,
    DateTime? updatedAt,
  }) {
    return GroupMedia(
      id: id,
      adminGroupId: adminGroupId,
      url: url ?? this.url,
      type: type ?? this.type,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      isVisible: isVisible ?? this.isVisible,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
