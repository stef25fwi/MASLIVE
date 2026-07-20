import 'dart:collection';

const int defaultMediaGalleryPageSize = 30;
const int maxMediaGalleryPageSize = 60;

int normalizeMediaGalleryPageSize(int? value) {
  final requested = value ?? defaultMediaGalleryPageSize;
  if (requested < 1) return 1;
  if (requested > maxMediaGalleryPageSize) return maxMediaGalleryPageSize;
  return requested;
}

class MediaGalleryCursor {
  const MediaGalleryCursor({
    required this.createdAtMillis,
    required this.photoId,
  });

  final int createdAtMillis;
  final String photoId;

  Map<String, Object> toMap() => <String, Object>{
        'createdAtMillis': createdAtMillis,
        'photoId': photoId,
      };

  static MediaGalleryCursor? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final createdAtMillis = (map['createdAtMillis'] as num?)?.toInt();
    final photoId = (map['photoId'] as String?)?.trim() ?? '';
    if (createdAtMillis == null || photoId.isEmpty) return null;
    return MediaGalleryCursor(
      createdAtMillis: createdAtMillis,
      photoId: photoId,
    );
  }
}

class MediaGalleryPage<T> {
  const MediaGalleryPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final MediaGalleryCursor? nextCursor;
}

class MediaGalleryPaginationState<T> {
  MediaGalleryPaginationState({
    this.pageSize = defaultMediaGalleryPageSize,
  }) : pageSize = normalizeMediaGalleryPageSize(pageSize);

  final int pageSize;
  final LinkedHashMap<String, T> _itemsById = LinkedHashMap<String, T>();

  MediaGalleryCursor? _cursor;
  bool _hasMore = true;
  bool _loading = false;

  List<T> get items => List<T>.unmodifiable(_itemsById.values);
  MediaGalleryCursor? get cursor => _cursor;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get canLoadMore => !_loading && _hasMore;

  bool beginLoad() {
    if (!canLoadMore) return false;
    _loading = true;
    return true;
  }

  void completePage(
    MediaGalleryPage<T> page, {
    required String Function(T item) idOf,
  }) {
    for (final item in page.items) {
      final id = idOf(item).trim();
      if (id.isEmpty) continue;
      _itemsById[id] = item;
    }
    _cursor = page.nextCursor;
    _hasMore = page.hasMore && page.nextCursor != null;
    _loading = false;
  }

  void failLoad() {
    _loading = false;
  }

  void reset() {
    _itemsById.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
  }
}
