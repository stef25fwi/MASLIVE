import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/domain/models/photo_search_query.dart';

void main() {
  test('normalizes participant metadata for Firestore', () {
    final query = PhotoSearchQuery(
      circuitId: ' circuit-1 ',
      eventDate: DateTime(2026, 7, 18),
      approximateTime: DateTime(2026, 7, 18, 9, 45),
      participantNumber: ' a12 ',
      outfitColor: ' ROUGE ',
      bibNumber: ' b42 ',
      group: ' Elite ',
      team: ' Karukera ',
      participantQrCode: 'qr-123',
    );

    expect(query.isEmpty, isFalse);
    expect(query.toFirestoreFilters(), <String, dynamic>{
      'circuitId': 'circuit-1',
      'eventDay': '2026-07-18',
      'approximateMinute': 585,
      'participantNumber': 'A12',
      'outfitColor': 'rouge',
      'bibNumber': 'B42',
      'group': 'elite',
      'team': 'karukera',
      'participantQrCode': 'qr-123',
    });
  });

  test('empty query does not emit filters', () {
    const query = PhotoSearchQuery();
    expect(query.isEmpty, isTrue);
    expect(query.toFirestoreFilters(), isEmpty);
    expect(query.toNormalizedTags(), isEmpty);
  });
}
