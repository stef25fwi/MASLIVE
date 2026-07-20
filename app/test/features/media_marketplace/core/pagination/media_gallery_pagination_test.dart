import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/core/pagination/media_gallery_pagination.dart';

void main() {
  group('normalizeMediaGalleryPageSize', () {
    test('applique une taille bornée', () {
      expect(normalizeMediaGalleryPageSize(null), defaultMediaGalleryPageSize);
      expect(normalizeMediaGalleryPageSize(0), 1);
      expect(normalizeMediaGalleryPageSize(45), 45);
      expect(normalizeMediaGalleryPageSize(500), maxMediaGalleryPageSize);
    });
  });

  group('MediaGalleryCursor', () {
    test('sérialise et restaure un curseur stable', () {
      const cursor = MediaGalleryCursor(
        createdAtMillis: 123456,
        photoId: 'photo_42',
      );
      expect(MediaGalleryCursor.fromMap(cursor.toMap())?.photoId, 'photo_42');
      expect(MediaGalleryCursor.fromMap(<String, dynamic>{}), isNull);
    });
  });

  group('MediaGalleryPaginationState', () {
    test('normalise la taille fournie au constructeur', () {
      expect(MediaGalleryPaginationState<String>(pageSize: 0).pageSize, 1);
      expect(
        MediaGalleryPaginationState<String>(pageSize: 1000).pageSize,
        maxMediaGalleryPageSize,
      );
    });

    test('empêche deux chargements simultanés', () {
      final state = MediaGalleryPaginationState<String>();
      expect(state.beginLoad(), isTrue);
      expect(state.beginLoad(), isFalse);
      state.failLoad();
      expect(state.beginLoad(), isTrue);
    });

    test('déduplique les photos entre deux pages', () {
      final state = MediaGalleryPaginationState<String>();
      expect(state.beginLoad(), isTrue);
      state.completePage(
        const MediaGalleryPage<String>(
          items: <String>['a', 'b'],
          hasMore: true,
          nextCursor: MediaGalleryCursor(
            createdAtMillis: 20,
            photoId: 'b',
          ),
        ),
        idOf: (item) => item,
      );
      expect(state.beginLoad(), isTrue);
      state.completePage(
        const MediaGalleryPage<String>(
          items: <String>['b', 'c'],
          hasMore: false,
        ),
        idOf: (item) => item,
      );
      expect(state.items, <String>['a', 'b', 'c']);
      expect(state.hasMore, isFalse);
      expect(state.canLoadMore, isFalse);
    });

    test('une page suivante exige un curseur', () {
      final state = MediaGalleryPaginationState<String>();
      state.beginLoad();
      state.completePage(
        const MediaGalleryPage<String>(
          items: <String>['a'],
          hasMore: true,
        ),
        idOf: (item) => item,
      );
      expect(state.hasMore, isFalse);
    });

    test('reset réinitialise entièrement la pagination', () {
      final state = MediaGalleryPaginationState<String>();
      state.beginLoad();
      state.completePage(
        const MediaGalleryPage<String>(
          items: <String>['a'],
          hasMore: true,
          nextCursor: MediaGalleryCursor(
            createdAtMillis: 10,
            photoId: 'a',
          ),
        ),
        idOf: (item) => item,
      );
      state.reset();
      expect(state.items, isEmpty);
      expect(state.cursor, isNull);
      expect(state.hasMore, isTrue);
      expect(state.loading, isFalse);
    });
  });
}
