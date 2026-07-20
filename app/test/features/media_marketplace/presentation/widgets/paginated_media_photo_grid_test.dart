import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/presentation/widgets/paginated_media_photo_grid.dart';

void main() {
  group('mediaPhotoGridColumnCount', () {
    test('utilise deux colonnes sur mobile', () {
      expect(mediaPhotoGridColumnCount(320), 2);
      expect(mediaPhotoGridColumnCount(619), 2);
    });

    test('augmente progressivement le nombre de colonnes', () {
      expect(mediaPhotoGridColumnCount(620), 3);
      expect(mediaPhotoGridColumnCount(900), 4);
      expect(mediaPhotoGridColumnCount(1180), 5);
      expect(mediaPhotoGridColumnCount(1500), 6);
    });
  });
}
