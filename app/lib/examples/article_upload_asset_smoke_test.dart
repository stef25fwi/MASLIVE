import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/storage_service.dart';
import '../services/superadmin_article_service.dart';

/// Smoke test manuel: crée un article et upload une image depuis les assets.
///
/// Usage:
/// - Lancer l'app (web/mobile) en étant loggé superadmin
/// - Naviguer vers ce widget temporairement (ou l'appeler via un bouton debug)
/// - Cliquer "Créer article test (asset)"
class ArticleUploadAssetSmokeTest extends StatefulWidget {
  const ArticleUploadAssetSmokeTest({super.key});

  @override
  State<ArticleUploadAssetSmokeTest> createState() => _ArticleUploadAssetSmokeTestState();
}

class _ArticleUploadAssetSmokeTestState extends State<ArticleUploadAssetSmokeTest> {
  final _storage = StorageService.instance;
  final _articles = SuperadminArticleService();

  bool _running = false;
  String _log = '';

  void _append(String msg) {
    setState(() => _log = '$_log$msg\n');
  }

  Future<void> _run() async {
    if (_running) return;

    setState(() {
      _running = true;
      _log = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      _append('✅ User: ${user.uid}');

      // Générer ID stable pour l'article
      final articleId = 'smoke_${DateTime.now().millisecondsSinceEpoch}';
      _append('🆔 Article ID: $articleId');

      // Upload image depuis asset
      final coverUrl = await _storage.uploadArticleFromAsset(
        articleId: articleId,
        assetPath: 'assets/images/maslivelogo.png',
        onProgress: (p) => _append('📦 Upload ${(p * 100).toStringAsFixed(0)}%'),
      );
      _append('✅ Cover URL: $coverUrl');

      // Créer article dans Firestore
      await _articles.createArticle(
        name: 'TEST ASSET $articleId',
        description: 'Smoke test: upload asset + création article',
        category: 'casquette',
        price: 9.99,
        imageUrl: coverUrl,
        stock: 1,
        sku: articleId,
        metadata: {
          'smokeTest': true,
          'source': 'asset',
        },
      );

      _append('✅ Article créé dans Firestore');
    } catch (e) {
      _append('❌ ERREUR: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smoke test upload article asset')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'En cours...' : 'Créer article test (asset)'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
