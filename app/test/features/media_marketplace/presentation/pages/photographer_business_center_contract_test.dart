import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final center = File(
    'lib/features/media_marketplace/presentation/pages/'
    'photographer_business_center_page.dart',
  ).readAsStringSync();
  final dashboard = File(
    'lib/features/media_marketplace/presentation/pages/'
    'photographer_dashboard_page.dart',
  ).readAsStringSync();

  test('le profil photographe est créable et modifiable', () {
    expect(center, contains('Créer mon profil photographe'));
    expect(center, contains('Modifier mon profil photographe'));
    expect(center, contains("collection('photographer_profiles')"));
    expect(dashboard, contains('Créer mon profil'));
  });

  test('les photos sont paginées et gérables individuellement ou par lot', () {
    expect(center, contains('static const int _pageSize = 30'));
    expect(center, contains('startAfterDocument'));
    expect(center, contains('Charger plus de photos'));
    expect(center, contains('_batchPatch'));
    expect(center, contains('_editPrice'));
    expect(center, contains('_deleteSelected'));
  });

  test('le quota de galeries est visible', () {
    expect(dashboard, contains('galeries actives'));
    expect(dashboard, contains('plan.maxActiveGalleries'));
  });

  test('les ventes détaillent frais et revenus nets', () {
    expect(center, contains('Commission plateforme'));
    expect(center, contains('Frais Stripe'));
    expect(center, contains('Net reversable'));
    expect(center, contains('photographerNetTotal'));
  });

  test('le cycle de vie de abonnement est accessible', () {
    expect(center, contains('createPhotographerBillingPortalLink'));
    expect(center, contains('cancelPhotographerSubscription'));
    expect(center, contains('resumePhotographerSubscription'));
    expect(dashboard, contains('Abonnement et factures'));
  });
}
