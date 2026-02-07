import 'dart:io';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/image_asset.dart';

void _out(String message) {
  stdout.writeln(message);
  developer.log(message);
}

/// Simple migration script placeholder
Future<void> main() async {
  _out('Migration images script');
}

class MigrationReport {
  int migrated = 0;
  int skipped = 0;
  int alreadyMigrated = 0;
  final List<String> errors = <String>[];

  void merge(MigrationReport other) {
    migrated += other.migrated;
    skipped += other.skipped;
    alreadyMigrated += other.alreadyMigrated;
    errors.addAll(other.errors);
  }

  @override
  String toString() {
    final b = StringBuffer();
    b.writeln('migrated=$migrated');
    b.writeln('skipped=$skipped');
    b.writeln('alreadyMigrated=$alreadyMigrated');
    if (errors.isNotEmpty) {
      b.writeln('errors=${errors.length}');
      for (final e in errors) {
        b.writeln('- $e');
      }
    }
    return b.toString().trimRight();
  }
}

/// Script de migration.
///
/// Convertit un champ URL unique (ex: `imageUrl`) vers le nouveau système `ImageAsset`
/// + référence (ex: `coverImageId`) sur le document parent.
class MigrationScript {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<MigrationReport> migrateAllImages({
    bool dryRun = true,
  }) async {
    final report = MigrationReport();

    _out('==== MIGRATION IMAGES ====');
    _out('Mode: ${dryRun ? 'DRY RUN (test)' : 'PRODUCTION'}');

    // 1) Articles superadmin
    _out('📄 Migration superadmin_articles');
    report.merge(
      await _migrateCollection(
        collectionPath: 'superadmin_articles',
        imageFieldName: 'imageUrl',
        imageRefFieldName: 'coverImageId',
        contentType: ImageContentType.articleCover,
        dryRun: dryRun,
      ),
    );

    // 2) Produits (legacy: collection "articles")
    _out('🛒 Migration articles (produits)');
    report.merge(
      await _migrateCollection(
        collectionPath: 'articles',
        imageFieldName: 'imageUrl',
        imageRefFieldName: 'coverImageId',
        contentType: ImageContentType.productPhoto,
        dryRun: dryRun,
      ),
    );

    _out('==== RAPPORT MIGRATION ====');
    _out(report.toString());

    return report;
  }

  static Future<MigrationReport> _migrateCollection({
    required String collectionPath,
    required String imageFieldName,
    required String imageRefFieldName,
    required ImageContentType contentType,
    bool dryRun = true,
    bool deleteLegacyField = false,
  }) async {
    final report = MigrationReport();

    try {
      final snapshot = await _firestore.collection(collectionPath).get();
      _out('  ${snapshot.docs.length} documents');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final imageUrl = data[imageFieldName] as String?;

        if (imageUrl == null || imageUrl.isEmpty) {
          report.skipped++;
          continue;
        }

        if (data.containsKey(imageRefFieldName)) {
          report.alreadyMigrated++;
          continue;
        }

        if (dryRun) {
          _out('  [DRY] ${doc.id}: $imageUrl');
          continue;
        }

        final imageAsset = await _createImageAssetFromUrl(
          imageUrl: imageUrl,
          parentId: doc.id,
          contentType: contentType,
        );

        final update = <String, Object?>{
          imageRefFieldName: imageAsset.id,
          'migratedAt': FieldValue.serverTimestamp(),
        };
        if (deleteLegacyField) {
          update[imageFieldName] = FieldValue.delete();
        }

        await doc.reference.update(update);
        report.migrated++;
      }
    } catch (e) {
      report.errors.add('Collection $collectionPath: $e');
    }

    return report;
  }

  static Future<ImageAsset> _createImageAssetFromUrl({
    required String imageUrl,
    required String parentId,
    required ImageContentType contentType,
  }) async {
    final ref = FirebaseStorage.instance.refFromURL(imageUrl);
    final meta = await ref.getMetadata();

    final now = DateTime.now();
    final imageId = 'img_${parentId}_${now.millisecondsSinceEpoch}';

    final imageAsset = ImageAsset(
      id: imageId,
      contentType: contentType,
      parentId: parentId,
      variants: ImageVariants(original: imageUrl),
      metadata: ImageMetadata(
        uploadedBy: FirebaseAuth.instance.currentUser?.uid ?? 'migration',
        uploadedAt: now,
        originalFilename: meta.name,
        sizeBytes: meta.size,
        mimeType: meta.contentType,
      ),
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('image_assets').doc(imageId).set(imageAsset.toMap());
    return imageAsset;
  }
}

