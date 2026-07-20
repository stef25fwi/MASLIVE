import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String relativePath) => File(relativePath).readAsStringSync();

void main() {
  test('les profils fonctionnels cumulent leurs capacités', () {
    final policy = source('lib/security/profile_capability_policy.dart');
    expect(policy, contains('final Set<ProfileKind> activeKinds;'));
    expect(policy, contains('_capabilitiesForAll(activeKinds)'));
    expect(policy, contains('kinds.add(ProfileKind.artisanArt)'));
    expect(policy, contains('kinds.add(ProfileKind.creatorDigital)'));
    expect(policy, contains('kinds.add(ProfileKind.groupAdmin)'));
    expect(policy, contains('kinds.add(ProfileKind.tracker)'));
  });

  test('l inbox vendeur est conditionnée par une capacité vendeur', () {
    final account = source('lib/pages/account_page.dart');
    final inbox = source('lib/pages/seller/seller_inbox_page.dart');
    expect(account, contains('if (profile.canManageSellerInbox)'));
    expect(inbox, contains('CapabilityGuard.any'));
    expect(inbox, contains('Capability.manageOwnGallery'));
    expect(inbox, contains('Capability.manageArtGallery'));
    expect(inbox, contains('Capability.manageGroupShop'));
  });

  test('le compte personnel et l administration sont séparés', () {
    final page = source('lib/pages/account_admin_page.dart');
    expect(page, contains("settings.name == '/account-admin'"));
    expect(page, contains('_buildPersonalAccountPage'));
    expect(page, contains('_buildAdminPage'));
    expect(page, contains('Capability.accessAdminPanel'));
  });

  test('aucune autorisation SuperAdmin ne dépend d une adresse e-mail', () {
    final page = source('lib/pages/account_admin_page.dart');
    expect(page, isNot(contains('s-stephane@live.fr')));
    expect(page, isNot(contains('isStephane')));
    expect(page, contains('ProfileKind.superAdmin'));
  });

  test('le parcours Admin Groupe distingue demande, attente, refus et approbation', () {
    final page = source('lib/pages/group/admin_group_dashboard_page.dart');
    expect(page, contains('Demander l’activation'));
    expect(page, contains('Demande en attente'));
    expect(page, contains('Demande refusée'));
    expect(page, contains('Capability.manageGroupTracking'));
    expect(page, isNot(contains('Créer mon profil Admin')));
  });

  test('le Compte Pro générique redirige vers les profils métier', () {
    final policy = source('lib/security/profile_capability_policy.dart');
    final request = source('lib/pages/business_request_page.dart');
    final account = source('lib/pages/business_account_page.dart');
    expect(policy, contains('hasBusiness: false'));
    expect(request, contains('Le Compte Pro générique a été remplacé'));
    expect(request, contains('Artisan d’art'));
    expect(request, contains('Créateur digital / photographe'));
    expect(request, contains('Admin Groupe'));
    expect(account, contains('BusinessRequestPage'));
  });

  test('les espaces photographe, Bloom Art, tracker et vendeur sont gardés', () {
    final media = source(
      'lib/features/media_marketplace/presentation/pages/media_marketplace_pages.dart',
    );
    final bloom = source(
      'lib/features/bloom_art/presentation/pages/bloom_art_pages.dart',
    );
    final tracker = source('lib/pages/group/tracker_group_profile_page.dart');
    final sellerOrder = source('lib/pages/seller/seller_order_detail_page.dart');
    expect(media, contains('Capability.manageOwnGallery'));
    expect(bloom, contains('Capability.manageArtGallery'));
    expect(bloom, contains('Capability.submitArtwork'));
    expect(tracker, contains('Capability.trackOwnLocation'));
    expect(sellerOrder, contains('CapabilityGuard.any'));
    expect(sellerOrder, contains('sellerStatuses.$uid'));
  });
}
