import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/image_management_service.dart';
import '../models/image_asset.dart';

/// SCRIPT DE MIGRATION
/// Convertit les images existantes (imageUrl unique) vers le nouveau système (ImageAsset)
///
/// USAGE:
/// ```dart
/// await MigrationScript.migrateAllImages(
///   dryRun: true, // Tester d'abord sans modifications
/// );
/// 
/// // Une fois validé:
/// await MigrationScript.migrateAllImages(
///   dryRun: false, // Vraie migration
/// );
/// ```

class MigrationScript {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final ImageManagementService _imageService =
      ImageManagementService.instance;

  /// Migrer toutes les collections
  static Future<MigrationReport> migrateAllImages({
    bool dryRun = true,
  }) async {
    print('\n==== MIGRATION IMAGES ====');
    print('Mode: ${dryRun ? 'DRY RUN (test)' : 'PRODUCTION'}');
    print('');

    final report = MigrationReport();

    // 1. Migrer articles
    print('📄 Migration articles...');
    final articlesReport = await _migrateCollection(
      collectionPath: 'superadmin_articles',
      imageFieldName: 'imageUrl',
      contentType: ImageContentType.articleCover,
      dryRun: dryRun,
    );
    report.merge(articlesReport);

    // 2. Migrer produits
    print('\n🛒 Migration produits...');
    final productsReport = await _migrateCollection(
      collectionPath: 'articles',
      imageFieldName: 'imageUrl',
      contentType: ImageContentType.productPhoto,
      dryRun: dryRun,
    );
    report.merge(productsReport);

    // 3. Migrer utilisateurs
    print('\n👤 Migration avatars utilisateurs...');
    final usersReport = await _migrateCollection(
      collectionPath: 'users',
      imageFieldName: 'profileImageUrl',
      contentType: ImageContentType.userAvatar,
      dryRun: dryRun,
    );
    report.merge(usersReport);

    // 4. Migrer groupes
    print('\n👥 Migration groupes...');
    final groupsReport = await _migrateCollection(
      collectionPath: 'groups',
      imageFieldName: 'imageUrl',
      contentType: ImageContentType.groupPhoto,
      dryRun: dryRun,
    );
    report.merge(groupsReport);

    // Rapport final
    print('\n==== RAPPORT MIGRATION ====');
    print(report.toString());

    return report;
  }

  /// Migrer une collection Firestore
  static Future<MigrationReport> _migrateCollection({
    required String collectionPath,
    required String imageFieldName,
    required ImageContentType contentType,
    bool dryRun = true,
  }) async {
    final report = MigrationReport();

    try {
      // Récupérer tous les documents
      final snapshot = await _firestore.collection(collectionPath).get();

      print('  ℹ️  ${snapshot.docs.length} documents trouvés');

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final imageUrl = data[imageFieldName] as String?;

          // Ignorer si pas d'image
          if (imageUrl == null || imageUrl.isEmpty) {
            report.skipped++;
            continue;
          }

          // Vérifier si déjà migré
          if (data.containsKey('coverImageId')) {
            print('  ⏭️  ${doc.id}: Déjà migré');
            report.alreadyMigrated++;
            continue;
          }

          if (dryRun) {
            print('  [DRY] ${doc.id}: Migrerait $imageUrl');
            report.wouldMigrate++;
            continue;
          }

          // Migration réelle
          print('  🔄 ${doc.id}: Migration...');

          // Créer ImageAsset à partir de l'URL existante
          final imageAsset = await _createImageAssetFromUrl(
            imageUrl: imageUrl,
            parentId: doc.id,
            contentType: contentType,
          );

          // Mettre à jour le document
          await doc.reference.update({
            'coverImageId': imageAsset.id,
            'imageUrl': FieldValue
                .delete(), // Supprimer ancien champ (optionnel, garder pour backup)
            'migratedAt': FieldValue.serverTimestamp(),
          });

          print('  ✅ ${doc.id}: Migré avec succès');
          report.migrated++;
        } catch (e) {
          print('  ❌ ${doc.id}: ERREUR - $e');
          report.errors.add('${doc.id}: $e');
        }
      }
    } catch (e) {
      print('  ❌ ERREUR COLLECTION: $e');
      report.errors.add('Collection $collectionPath: $e');
    }

    return report;
  }

  /// Créer ImageAsset à partir d'une URL existante
  static Future<ImageAsset> _createImageAssetFromUrl({
    required String imageUrl,
    required String parentId,
    required ImageContentType contentType,
  }) async {
    try {
      // 1. Télécharger l'image originale depuis Storage
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      final metadata = await ref.getMetadata();

      // 2. Créer ImageAsset dans Firestore
      final now = DateTime.now();
      final imageId =
          'img_${parentId}_${now.millisecondsSinceEpoch}'; // ID unique

      final imageAsset = ImageAsset(
        id: imageId,
        contentType: contentType,
        parentId: parentId,
        variants: ImageVariants(
          original: imageUrl, // URL originale conservée
          // Les variants seront générés par Cloud Function automatiquement
        ),
        metadata: ImageMetadata(
          uploadedBy: FirebaseAuth.instance.currentUser?.uid ?? 'migration',
          uploadedAt: now,
          fileSize: metadata.size ?? 0,
          mimeType: metadata.contentType ?? 'image/jpeg',
        ),
        order: 0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // 3. Sauvegarder dans Firestore
      await _firestore
          .collection('image_assets')
          .doc(imageId)
          .set(imageAsset.toMap());

      // 4. La Cloud Function détectera l'upload et générera les variants automatiquement
      // via le trigger generateImageVariants

      return imageAsset;
    } catch (e) {
      print('    ⚠️  Erreur création ImageAsset: $e');
      rethrow;
    }
  }

  /// Migrer un seul document (pour tests)
  static Future<void> migrateSingleDocument({
    required String collectionPath,
    required String documentId,
    required String imageFieldName,
    required ImageContentType contentType,
  }) async {
    print('\n==== MIGRATION DOCUMENT UNIQUE ====');
    print('Collection: $collectionPath');
    print('Document: $documentId');

    final doc = await _firestore.collection(collectionPath).doc(documentId).get();

    if (!doc.exists) {
      print('❌ Document introuvable');
      return;
    }

    final data = doc.data()!;
    final imageUrl = data[imageFieldName] as String?;

    if (imageUrl == null || imageUrl.isEmpty) {
      print('❌ Pas d\'image à migrer');
      return;
    }

    print('📷 Image actuelle: $imageUrl');

    // Migration
    final imageAsset = await _createImageAssetFromUrl(
      imageUrl: imageUrl,
      parentId: doc.id,
      contentType: contentType,
    );

    await doc.reference.update({
      'coverImageId': imageAsset.id,
      'migratedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Migration réussie');
    print('   ID ImageAsset: ${imageAsset.id}');
  }

  /// Nettoyer les anciens champs (après validation)
  static Future<void> cleanupOldFields({
    required String collectionPath,
    required String fieldName,
  }) async {
    print('\n==== NETTOYAGE ANCIENS CHAMPS ====');
    print('Collection: $collectionPath');
    print('Champ: $fieldName');

    final snapshot = await _firestore
        .collection(collectionPath)
        .where(fieldName, isNull: false)
        .get();

    print('${snapshot.docs.length} documents à nettoyer');

    int cleaned = 0;
    for (final doc in snapshot.docs) {
      await doc.reference.update({
        fieldName: FieldValue.delete(),
      });
      cleaned++;
      print('  ✅ ${doc.id}');
    }

    print('✅ $cleaned documents nettoyés');
  }

  /// Rollback migration (en cas de problème)
  static Future<void> rollbackMigration({
    required String collectionPath,
  }) async {
    print('\n==== ROLLBACK MIGRATION ====');
    print('Collection: $collectionPath');
    print('⚠️  ATTENTION: Cette opération inverse la migration');

    final snapshot = await _firestore
        .collection(collectionPath)
        .where('coverImageId', isNull: false)
        .get();

    print('${snapshot.docs.length} documents à revenir');

    int rolledBack = 0;
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final coverImageId = data['coverImageId'] as String?;

        if (coverImageId == null) continue;

        // Récupérer ImageAsset
        final imageAssetDoc =
            await _firestore.collection('image_assets').doc(coverImageId).get();

        if (!imageAssetDoc.exists) continue;

        final imageAsset = ImageAsset.fromMap(imageAssetDoc.data()!);

        // Restaurer imageUrl
        await doc.reference.update({
          'imageUrl': imageAsset.variants.original,
          'coverImageId': FieldValue.delete(),
          'migratedAt': FieldValue.delete(),
          'rolledBackAt': FieldValue.serverTimestamp(),
        });

        rolledBack++;
        print('  ✅ ${doc.id}');
      } catch (e) {
        print('  ❌ ${doc.id}: $e');
      }
    }

    print('✅ $rolledBack documents restaurés');
  }
}

/// Rapport de migration
class MigrationReport {
  int migrated = 0;
  int alreadyMigrated = 0;
  int wouldMigrate = 0;
  int skipped = 0;
  final List<String> errors = [];

  void merge(MigrationReport other) {
    migrated += other.migrated;
    alreadyMigrated += other.alreadyMigrated;
    wouldMigrate += other.wouldMigrate;
    skipped += other.skipped;
    errors.addAll(other.errors);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Migrés: $migrated');
    buffer.writeln('Déjà migrés: $alreadyMigrated');
    if (wouldMigrate > 0) {
      buffer.writeln('À migrer: $wouldMigrate');
    }
    buffer.writeln('Ignorés (pas d\'image): $skipped');
    if (errors.isNotEmpty) {
      buffer.writeln('Erreurs: ${errors.length}');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }
    return buffer.toString();
  }
}

/// EXEMPLE D'UTILISATION
void main() async {
  // Initialiser Firebase
  await Firebase.initializeApp();

  // 1. Test en dry run (aucune modification)
  print('🧪 Test migration (dry run)...\n');
  var report = await MigrationScript.migrateAllImages(dryRun: true);
  print(report);

  // 2. Confirmer avant migration réelle
  print('\n⚠️  Démarrer la migration réelle ? (y/n)');
  final input = stdin.readLineSync();

  if (input?.toLowerCase() == 'y') {
    print('\n🚀 Migration en cours...\n');
    report = await MigrationScript.migrateAllImages(dryRun: false);
    print(report);
    print('\n✅ Migration terminée !');
  } else {
    print('❌ Migration annulée');
  }
}
