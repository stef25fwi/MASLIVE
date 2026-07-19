import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/data/models/media_photo_model.dart';

void main() {
  test('la boutique préfère la preview filigranée', () {
    final photo = MediaPhotoModel.fromMap(<String, dynamic>{
      'photoId': 'photo-1',
      'photographerId': 'photographer-1',
      'ownerUid': 'owner-1',
      'galleryId': 'gallery-1',
      'eventId': 'event-1',
      'countryId': 'gp',
      'circuitId': 'circuit-1',
      'originalPath': 'private/original.jpg',
      'previewPath': 'private/preview.webp',
      'thumbnailPath': 'public/thumb.webp',
      'watermarkedPath': 'public/watermarked.webp',
      'downloadFileName': 'photo.jpg',
    });

    expect(photo.previewPath, 'public/watermarked.webp');
    expect(photo.watermarkedPath, 'public/watermarked.webp');
    expect(photo.originalPath, 'private/original.jpg');
  });

  test('la miniature sert de repli si aucun aperçu n’existe', () {
    final photo = MediaPhotoModel.fromMap(<String, dynamic>{
      'photoId': 'photo-2',
      'photographerId': 'photographer-1',
      'ownerUid': 'owner-1',
      'galleryId': 'gallery-1',
      'eventId': 'event-1',
      'countryId': 'gp',
      'circuitId': 'circuit-1',
      'originalPath': 'private/original.jpg',
      'thumbnailPath': 'public/thumb.webp',
      'downloadFileName': 'photo.jpg',
    });

    expect(photo.previewPath, 'public/thumb.webp');
  });
}
