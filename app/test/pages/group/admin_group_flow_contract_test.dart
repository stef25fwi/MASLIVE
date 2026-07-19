import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le dashboard admin expose le parcours groupe unifié', () {
    final source = File(
      'lib/pages/group/admin_group_dashboard_page.dart',
    ).readAsStringSync();

    expect(source, contains('Parcours du groupe'));
    expect(source, contains('Créer → Inviter → Associer'));
    expect(source, contains('_requestTrackingConsent'));
    expect(source, contains("role: 'admin'"));
    expect(source, contains('recordAcceptance'));
    expect(source, contains('Session du groupe arrêtée'));
    expect(source, contains('Voir l’historique'));
  });
}
