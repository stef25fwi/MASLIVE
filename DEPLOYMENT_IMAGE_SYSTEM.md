# 🚀 DÉPLOIEMENT SYSTÈME IMAGES - GUIDE COMPLET

## Étape 1: Installation des dépendances (5 min)

### Flutter (app/)
```bash
cd /workspaces/MASLIVE/app
flutter pub add cached_network_image image
flutter pub get
```

### Cloud Functions (functions/)
```bash
cd /workspaces/MASLIVE/functions
npm install sharp@^0.33.0
```

---

## Étape 2: Configurer Firebase (10 min)

### 2.1 Firestore Rules

Ajouter dans `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Collection image_assets
    match /image_assets/{imageId} {
      // Lecture: authentifié ou public selon contentType
      allow read: if request.auth != null 
                  || resource.data.contentType in ['productPhoto', 'articleCover'];
      
      // Création: authentifié seulement
      allow create: if request.auth != null
                    && request.resource.data.metadata.uploadedBy == request.auth.uid
                    && request.resource.data.isActive == true;
      
      // Mise à jour: propriétaire ou admin
      allow update: if request.auth != null
                    && (resource.data.metadata.uploadedBy == request.auth.uid
                        || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true);
      
      // Suppression: propriétaire ou admin (soft delete uniquement)
      allow delete: if false; // Utiliser soft delete (isActive=false) au lieu de delete
    }
    
    // Autres règles existantes...
  }
}
```

Déployer:
```bash
firebase deploy --only firestore:rules
```

### 2.2 Storage Rules

Ajouter dans `storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Images optimisées
    match /images/{contentType}/{parentId}/{imageId}/{variant} {
      // Lecture: public pour produits/articles, authentifié pour autres
      allow read: if contentType in ['productPhoto', 'articleCover'] 
                  || request.auth != null;
      
      // Écriture: authentifié + Cloud Functions
      allow write: if request.auth != null 
                   || request.auth.token.admin == true;
    }
    
    // Anciennes images (rétrocompatibilité)
    match /{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

Déployer:
```bash
firebase deploy --only storage:rules
```

---

## Étape 3: Déployer Cloud Functions (5 min)

### 3.1 Exporter les fonctions

Ajouter dans `functions/index.js` (ou `functions/src/index.ts`):

```javascript
// Import image functions
const imageVariants = require('./src/image-variants');

// Export
exports.generateImageVariants = imageVariants.generateImageVariants;
exports.regenerateImageVariants = imageVariants.regenerateImageVariants;
exports.cleanupDeletedImages = imageVariants.cleanupDeletedImages;
```

### 3.2 Déployer

```bash
cd /workspaces/MASLIVE
firebase deploy --only functions:generateImageVariants,functions:regenerateImageVariants,functions:cleanupDeletedImages
```

**Temps estimé:** 3-5 minutes

---

## Étape 4: Tester sur un document (15 min)

### 4.1 Test unitaire

Créer fichier `test_image_system.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/services/image_management_service.dart';
import '../lib/models/image_asset.dart';

void main() async {
  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('Upload et récupération image', () async {
    final service = ImageManagementService.instance;
    
    // Upload test
    final imageAsset = await service.uploadImage(
      file: /* test file */,
      contentType: ImageContentType.productPhoto,
      parentId: 'test_product',
      altText: 'Test image',
    );
    
    expect(imageAsset.id, isNotEmpty);
    expect(imageAsset.variants.original, isNotEmpty);
    
    // Récupération test
    final collection = await service.getImageCollection('test_product');
    expect(collection.hasImages, isTrue);
    expect(collection.coverImage?.id, imageAsset.id);
    
    // Cleanup
    await service.deleteImage(imageAsset.id);
  });
}
```

Exécuter:
```bash
flutter test test/test_image_system.dart
```

### 4.2 Test manuel dans l'app

1. **Créer un nouveau produit** avec images
2. **Vérifier dans Firebase Console:**
   - Collection `image_assets` contient document
   - Storage contient dossier avec 6 fichiers (original + 5 variants)
3. **Tester affichage** sur différentes tailles d'écran

---

## Étape 5: Migration données existantes (30 min)

### 5.1 Dry run (test sans modification)

```bash
cd /workspaces/MASLIVE/app
dart run lib/scripts/migrate_images.dart
# Automatiquement en mode dry run
```

Vérifier le rapport:
```
==== RAPPORT MIGRATION ====
Migrés: 0
Déjà migrés: 0
À migrer: 127
Ignorés (pas d'image): 45
Erreurs: 0
```

### 5.2 Migration réelle

Si rapport OK, confirmer avec 'y' dans le prompt.

Ou au code:
```dart
await MigrationScript.migrateAllImages(dryRun: false);
```

**⚠️ BACKUP FIRESTORE AVANT MIGRATION !**

```bash
# Backup automatique
gcloud firestore export gs://your-bucket/backup-$(date +%Y%m%d) --project=your-project-id
```

### 5.3 Validation

Vérifier quelques documents:
```dart
await MigrationScript.migrateSingleDocument(
  collectionPath: 'articles',
  documentId: 'ART123',
  imageFieldName: 'imageUrl',
  contentType: ImageContentType.productPhoto,
);
```

---

## Étape 6: Intégrer dans pages existantes (30 min)

### Exemple: Page création produit

**AVANT:**
```dart
// Ancien code
String? _imageUrl;

Future<void> _uploadImage(File file) async {
  final ref = FirebaseStorage.instance.ref('articles/${DateTime.now().millisecondsSinceEpoch}.jpg');
  await ref.putFile(file);
  _imageUrl = await ref.getDownloadURL();
  setState(() {});
}

// Affichage
if (_imageUrl != null)
  Image.network(_imageUrl!);
```

**APRÈS:**
```dart
// Nouveau code
ImageCollection? _imageCollection;

Future<void> _uploadImage(XFile file) async {
  final imageAsset = await ImageManagementService.instance.uploadImage(
    file: file,
    contentType: ImageContentType.productPhoto,
    parentId: widget.productId,
    onProgress: (progress) => setState(() => _uploadProgress = progress),
  );
  
  // Recharger collection
  _imageCollection = await ImageManagementService.instance
      .getImageCollection(widget.productId);
  setState(() {});
}

// Affichage
if (_imageCollection != null && _imageCollection!.hasImages)
  CoverImage(
    collection: _imageCollection!,
    preferredSize: ImageSize.medium,
    height: 200,
  );
```

Voir fichier complet: [image_management_integration_example.dart](../app/lib/examples/image_management_integration_example.dart)

---

## Étape 7: Déploiement production (15 min)

### 7.1 Build Flutter Web

```bash
cd /workspaces/MASLIVE/app
flutter build web --release
```

### 7.2 Déployer Hosting + Functions + Rules

```bash
cd /workspaces/MASLIVE
firebase deploy --only hosting,functions,firestore:rules,storage:rules
```

### 7.3 Vérifier

1. Ouvrir site en production
2. Créer un nouveau produit avec images
3. Vérifier variants générés dans Storage
4. Tester affichage adaptatif (mobile/desktop)

---

## 📊 Checklist finale

- [ ] Dependencies installées (cached_network_image, sharp)
- [ ] Firestore rules déployées
- [ ] Storage rules déployées
- [ ] Cloud Functions déployées
- [ ] Tests unitaires passent
- [ ] Test manuel réussi
- [ ] Migration dry run OK
- [ ] Migration production OK
- [ ] Au moins 1 page intégrée
- [ ] Monitoring activé (Cloud Functions logs)
- [ ] Backup Firestore créé
- [ ] Documentation équipe mise à jour

---

## ⚠️ Troubleshooting

### Cloud Function ne génère pas variants

**Symptômes:** Upload OK mais pas de thumbnail/small/medium/etc.

**Solutions:**
1. Vérifier logs Functions:
   ```bash
   firebase functions:log --only generateImageVariants
   ```

2. Vérifier fichier nommé "original.*":
   ```
   Storage path: images/productPhoto/PROD123/img_xxx/original.jpg ✅
   Storage path: images/productPhoto/PROD123/photo.jpg ❌
   ```

3. Tester regeneration manuelle:
   ```dart
   await ImageManagementService.instance._regenerateVariants('image_id');
   ```

### Images ne s'affichent pas

**Symptômes:** SmartImage affiche placeholder gris

**Solutions:**
1. Vérifier CORS Firebase Storage (déjà configuré normalement)
2. Vérifier Storage Rules autorisent lecture
3. Tester URL directement dans navigateur
4. Vérifier CachedNetworkImage dependencies

### Performance dégradée

**Symptômes:** Chargement lent malgré variants

**Solutions:**
1. Vérifier cache fonctionne:
   ```dart
   CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;
   ```

2. Preload images importantes:
   ```dart
   await precacheImage(CachedNetworkImageProvider(url), context);
   ```

3. Réduire résolution variants si nécessaire

---

## 📈 Monitoring

### Métriques à suivre

1. **Cloud Functions:**
   - Invocations generateImageVariants (devrait = nombre d'uploads)
   - Temps d'exécution (moyenne < 30s)
   - Erreurs (devrait être 0%)

2. **Firebase Storage:**
   - Bande passante sortante (devrait diminuer après migration)
   - Taille totale (augmente avec variants mais optimisé)

3. **Firestore:**
   - Lectures collection `image_assets`
   - Temps réponse requêtes

### Alertes recommandées

```bash
# Créer alerte si temps Functions > 180s
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Image variants slow" \
  --condition-threshold-value=180 \
  --condition-threshold-duration=60s
```

---

## 🎉 Résultat attendu

Après déploiement complet:

✅ Upload image → Génération automatique 5 variants en < 30s
✅ Affichage adaptatif selon taille écran
✅ Galeries plein écran avec zoom
✅ Temps chargement -70%
✅ Bande passante -60%
✅ UX fluide avec rainbow loading

**Durée totale: ~2 heures** (dont 30 min migration)

---

## 📚 Ressources

- [IMAGE_MANAGEMENT_SYSTEM.md](IMAGE_MANAGEMENT_SYSTEM.md) - Documentation complète
- [image_management_integration_example.dart](../app/lib/examples/image_management_integration_example.dart) - Exemples code
- [migrate_images.dart](../app/lib/scripts/migrate_images.dart) - Script migration

**Support:** Voir troubleshooting ou Firebase Console logs
