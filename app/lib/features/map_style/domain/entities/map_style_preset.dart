import 'map_style_enums.dart';
import 'map_style_theme.dart';

class MapStylePreset {
  const MapStylePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.thumbnailUrl,
    required this.dominantColor,
    required this.tags,
    required this.ownerUid,
    required this.orgId,
    required this.scope,
    required this.status,
    required this.visibleInWizard,
    required this.isQuickPreset,
    required this.isDefault,
    required this.theme,
    required this.usageCount,
    required this.referencesCount,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.archivedAt,
  });

  final String id;
  final String name;
  final String description;
  final MapStyleCategory category;
  final String thumbnailUrl;
  final String dominantColor;
  final List<String> tags;
  final String ownerUid;
  final String orgId;
  final MapStyleScope scope;
  final MapStyleStatus status;
  final bool visibleInWizard;
  final bool isQuickPreset;
  final bool isDefault;
  final MapStyleTheme theme;
  final int usageCount;
  final int referencesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  bool get canDelete => referencesCount <= 0;

  MapStylePreset copyWith({
    String? id,
    String? name,
    String? description,
    MapStyleCategory? category,
    String? thumbnailUrl,
    String? dominantColor,
    List<String>? tags,
    String? ownerUid,
    String? orgId,
    MapStyleScope? scope,
    MapStyleStatus? status,
    bool? visibleInWizard,
    bool? isQuickPreset,
    bool? isDefault,
    MapStyleTheme? theme,
    int? usageCount,
    int? referencesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) {
    return MapStylePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      dominantColor: dominantColor ?? this.dominantColor,
      tags: tags ?? this.tags,
      ownerUid: ownerUid ?? this.ownerUid,
      orgId: orgId ?? this.orgId,
      scope: scope ?? this.scope,
      status: status ?? this.status,
      visibleInWizard: visibleInWizard ?? this.visibleInWizard,
      isQuickPreset: isQuickPreset ?? this.isQuickPreset,
      isDefault: isDefault ?? this.isDefault,
      theme: theme ?? this.theme,
      usageCount: usageCount ?? this.usageCount,
      referencesCount: referencesCount ?? this.referencesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStylePreset &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.category == category &&
        other.thumbnailUrl == thumbnailUrl &&
        other.dominantColor == dominantColor &&
        _sameTags(other.tags, tags) &&
        other.ownerUid == ownerUid &&
        other.orgId == orgId &&
        other.scope == scope &&
        other.status == status &&
        other.visibleInWizard == visibleInWizard &&
        other.isQuickPreset == isQuickPreset &&
        other.isDefault == isDefault &&
        other.theme == theme &&
        other.usageCount == usageCount &&
        other.referencesCount == referencesCount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.publishedAt == publishedAt &&
        other.archivedAt == archivedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      id,
      name,
      description,
      category,
      thumbnailUrl,
      dominantColor,
      Object.hashAll(tags),
      ownerUid,
      orgId,
      scope,
      status,
      visibleInWizard,
      isQuickPreset,
      isDefault,
      theme,
      usageCount,
      referencesCount,
      createdAt,
      updatedAt,
      publishedAt,
      archivedAt,
    ]);
  }

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
