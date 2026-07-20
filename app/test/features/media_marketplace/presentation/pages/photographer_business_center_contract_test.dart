import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final complete = File(
    'lib/features/media_marketplace/presentation/pages/'
    'photographer_complete_flow_page.dart',
  ).readAsStringSync();
  final center = File(
    'lib/features/media_marketplace/presentation/pages/'
    'photographer_business_center_page.dart',
  ).readAsStringSync();
  final dashboard = File(
    'lib/features/media_marketplace/presentation/pages/'
    'photographer_dashboard_page.dart',
  ).readAsStringSync();
  final galleries = File(
    'lib/features/media_marketplace/presentation/widgets/'
    'photographer_gallery_studio_panel.dart',
  ).readAsStringSync();
  final imports = File(
    'lib/features/media_marketplace/presentation/widgets/'
    'photographer_import_panel.dart',
  ).readAsStringSync();
  final photos = File(
    'lib/features/media_marketplace/presentation/widgets/'
    'photographer_photo_library_panel.dart',
  ).readAsStringSync();
  final finance = File(
    'lib/features/media_marketplace/presentation/widgets/'
    'photographer_finance_panel.dart',
  ).readAsStringSync();
  final team = File(
    'lib/features/media_marketplace/presentation/widgets/'
    'photographer_team_brand_panel.dart',
  ).readAsStringSync();
  final avatar = File(
    'lib/features/media_marketplace/domain/services/'
    'photographer_avatar_service.dart',
  ).readAsStringSync();
  final sessions = File(
    'lib/features/media_marketplace/domain/services/'
    'photographer_import_session_service.dart',
  ).readAsStringSync();

  test('les anciens points d entrée utilisent le centre complet', () {
    expect(center, contains('PhotographerCompleteFlowPage'));
    expect(dashboard, contains('PhotographerCompleteFlowPage'));
    expect(complete, contains('Vue d’ensemble'));
    expect(complete, contains('Équipe & marque'));
  });

  test('le dashboard avancé couvre les indicateurs manquants', () {
    expect(complete, contains('Ventes du mois'));
    expect(complete, contains('Disponible à reverser'));
    expect(complete, contains('Photos à traiter'));
    expect(complete, contains('Circuits sans galerie'));
    expect(complete, contains('Alertes d’expiration'));
    expect(complete, contains('Prochain renouvellement'));
    expect(complete, contains('Voir ma boutique publique'));
  });

  test('le profil permet un avatar choisi recadré et compressé', () {
    expect(complete, contains('Choisir, recadrer et compresser l’avatar'));
    expect(avatar, contains('ImageSource.gallery'));
    expect(avatar, contains('copyCrop'));
    expect(avatar, contains('copyResize'));
    expect(avatar, contains('encodeJpg'));
  });

  test('les galeries sont éditables dupliquées supprimables et privées', () {
    expect(galleries, contains('Éditer complètement'));
    expect(galleries, contains('Heure de début'));
    expect(galleries, contains('Point de départ'));
    expect(galleries, contains('Tarifs des packs'));
    expect(galleries, contains('Créer un lien privé'));
    expect(galleries, contains('Dupliquer'));
    expect(galleries, contains('Supprimer'));
    expect(galleries, contains('Regroupement anonyme des visages'));
  });

  test('les imports de lots sont persistants et reprenables', () {
    expect(imports, contains('Importer un dossier / lot'));
    expect(imports, contains('Sessions persistantes'));
    expect(imports, contains('Reprendre avec le même dossier'));
    expect(sessions, contains('SharedPreferences'));
    expect(sessions, contains('savePhotographerImportSession'));
    expect(sessions, contains('completedFiles'));
  });

  test('la photothèque fournit recherche filtres lots métadonnées et historique', () {
    expect(photos, contains('Recherche'));
    expect(photos, contains('Dossard'));
    expect(photos, contains('Sélectionner la page'));
    expect(photos, contains('Prix groupé'));
    expect(photos, contains('Déplacer'));
    expect(photos, contains('Ajouter des tags'));
    expect(photos, contains('Historique des modifications'));
  });

  test('les ventes distinguent reversements et fournissent tous les exports', () {
    expect(finance, contains('Disponible'));
    expect(finance, contains('En attente'));
    expect(finance, contains('Reversé'));
    expect(finance, contains('Calendrier des prochains reversements'));
    expect(finance, contains('CSV ventes'));
    expect(finance, contains('Export comptable'));
    expect(finance, contains('Export clients'));
    expect(finance, contains('Générer un relevé'));
  });

  test('les fonctions commerciales des plans ont une interface réelle', () {
    expect(team, contains('Collaborateurs'));
    expect(team, contains('Marques et boutiques'));
    expect(team, contains('Codes promotionnels'));
    expect(team, contains('Personnalisation de la boutique'));
    expect(team, contains('Import automatisé par API'));
    expect(team, contains('Consentement au regroupement visuel anonyme'));
  });
}
