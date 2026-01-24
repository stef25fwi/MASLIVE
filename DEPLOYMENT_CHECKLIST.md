# ✅ Checklist de déploiement - Media Shop V2

## 📦 Fichiers créés

- [x] `/app/lib/pages/media_galleries_page_v2.dart` - Page principale avec shop
- [x] `/app/lib/pages/media_shop_wrapper.dart` - Wrapper avec CartProvider
- [x] `/scripts/migrate_media_galleries.js` - Script migration Firestore
- [x] `/MEDIA_SHOP_STRUCTURE.md` - Documentation complète
- [x] `/MEDIA_COMPARISON.md` - Comparaison ancienne vs nouvelle
- [x] `/FIRESTORE_EXAMPLES.md` - Exemples de données
- [x] `/INTEGRATION_EXAMPLES.dart` - Exemples d'intégration

## 🔧 Étapes de déploiement

### 1. Préparation Firestore

- [ ] **Sauvegarder** la collection `media_galleries` existante
  ```bash
  # Export depuis console Firebase ou CLI
  firebase firestore:export gs://your-bucket/backup
  ```

- [ ] **Exécuter** le script de migration
  ```bash
  cd /workspaces/MASLIVE
  node scripts/migrate_media_galleries.js
  ```

- [ ] **Vérifier** que les nouveaux champs sont présents
  - `country` (String)
  - `date` (Timestamp)
  - `eventName` (String)
  - `groupName` (String)
  - `photographerName` (String)
  - `pricePerPhoto` (Number)

- [ ] **Optionnel:** Créer une galerie de test
  ```bash
  node scripts/migrate_media_galleries.js --test
  ```

### 2. Tests en développement

- [ ] **Compiler** l'application sans erreurs
  ```bash
  cd /workspaces/MASLIVE/app
  flutter pub get
  flutter analyze
  ```

- [ ] **Tester** la nouvelle page
  ```dart
  // Dans un fichier de test ou page temporaire
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const MediaShopWrapper(groupId: 'all'),
    ),
  );
  ```

- [ ] **Vérifier** les fonctionnalités:
  - [ ] Affichage des galeries
  - [ ] Filtres fonctionnent
  - [ ] Filtres cascadés (pays → date → événement → groupe → photographe)
  - [ ] Sélection multiple (checkmarks)
  - [ ] Barre de sélection apparaît
  - [ ] Badge panier s'incrémente
  - [ ] Preview modale s'ouvre
  - [ ] Panier modal s'ouvre
  - [ ] Tri fonctionne

### 3. Intégration dans l'app

- [ ] **Choisir** le mode d'intégration (voir `INTEGRATION_EXAMPLES.dart`)
  - [ ] Option 1: Navigation simple
  - [ ] Option 2: Onglet BottomNavigationBar
  - [ ] Option 3: Route nommée
  - [ ] Option 4: Paramètre dynamique
  - [ ] Option 5: Panier global

- [ ] **Remplacer** les imports
  ```dart
  // AVANT
  import 'pages/media_galleries_page.dart';
  
  // APRÈS
  import 'pages/media_shop_wrapper.dart';
  ```

- [ ] **Remplacer** les usages
  ```dart
  // AVANT
  MediaGalleriesPage(groupId: 'all')
  
  // APRÈS
  MediaShopWrapper(groupId: 'all')
  ```

- [ ] **Tester** la navigation complète

### 4. Configuration checkout (optionnel)

- [ ] **Installer** Stripe Flutter
  ```bash
  flutter pub add stripe_checkout
  ```

- [ ] **Implémenter** le checkout dans `_openCartSheet()`
  ```dart
  // Remplacer le placeholder:
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Checkout à brancher (Stripe, etc.)')),
  );
  
  // Par votre logique Stripe
  ```

- [ ] **Tester** le paiement en mode test Stripe

### 5. Build & Deploy

- [ ] **Build Web** (si applicable)
  ```bash
  cd /workspaces/MASLIVE/app
  flutter build web --release
  ```

- [ ] **Build Android** (si applicable)
  ```bash
  flutter build apk --release
  # ou
  flutter build appbundle --release
  ```

- [ ] **Build iOS** (si applicable)
  ```bash
  flutter build ios --release
  ```

- [ ] **Déployer Firebase Hosting**
  ```bash
  cd /workspaces/MASLIVE
  firebase deploy --only hosting
  ```

### 6. Tests post-déploiement

- [ ] **Tester** sur production
  - [ ] Chargement des galeries
  - [ ] Filtres fonctionnent
  - [ ] Sélection fonctionne
  - [ ] Panier fonctionne
  - [ ] Preview modale fonctionne
  - [ ] Checkout fonctionne (si implémenté)

- [ ] **Tester** sur mobile (responsive)
  - [ ] iPhone / Android
  - [ ] Tablette
  - [ ] Orientations portrait/paysage

- [ ] **Vérifier** les performances
  - [ ] Temps de chargement < 3s
  - [ ] Scroll fluide
  - [ ] Pas de lag sur filtres

### 7. Monitoring

- [ ] **Activer** Firebase Analytics
  ```dart
  FirebaseAnalytics.instance.logEvent(
    name: 'gallery_view',
    parameters: {'gallery_id': gallery.id},
  );
  ```

- [ ] **Configurer** Crashlytics
  ```dart
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  ```

- [ ] **Suivre** les métriques:
  - Nombre de vues par galerie
  - Taux de conversion (vue → panier → achat)
  - Panier moyen
  - Photos les plus populaires

## 🚨 Rollback (si problème)

Si vous devez revenir à l'ancienne version:

1. **Restaurer** l'ancien fichier
   ```bash
   git checkout HEAD~1 -- app/lib/pages/media_galleries_page.dart
   ```

2. **Restaurer** les imports
   ```dart
   // Remettre
   import 'pages/media_galleries_page.dart';
   MediaGalleriesPage(groupId: 'all')
   ```

3. **Rebuild & redeploy**
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

## 📊 Métriques de succès

Après 1 semaine de déploiement, vérifier:

- [ ] **Engagement**
  - Temps moyen sur la page > 2min
  - Taux de rebond < 60%
  - Galeries vues par session > 5

- [ ] **Conversion**
  - Taux ajout au panier > 10%
  - Taux achat > 2%
  - Panier moyen > 3 galeries

- [ ] **Technique**
  - Taux d'erreur < 1%
  - Temps de chargement < 3s
  - Pas de crash

## 📝 Notes

### Anciennes galeries sans métadonnées

Si vous avez des galeries existantes sans les nouveaux champs:

1. Le script de migration applique des valeurs par défaut
2. Vous pouvez les éditer manuellement dans Firestore Console
3. Ou créer un formulaire admin pour édition en masse

### Évolution future

Fonctionnalités à ajouter:

- [ ] Persistance panier (SharedPreferences)
- [ ] Favoris
- [ ] Partage
- [ ] Téléchargement après achat
- [ ] Watermark sur preview
- [ ] Recherche textuelle
- [ ] Notifications (nouvelles galeries)
- [ ] Système de reviews/notes

### Support

En cas de problème:

1. Consulter [MEDIA_SHOP_STRUCTURE.md](MEDIA_SHOP_STRUCTURE.md)
2. Voir [INTEGRATION_EXAMPLES.dart](INTEGRATION_EXAMPLES.dart)
3. Vérifier [FIRESTORE_EXAMPLES.md](FIRESTORE_EXAMPLES.md)

---

## ✨ Déploiement terminé !

Une fois tous les points cochés, votre nouvelle page médias est prête !

Date de déploiement: _______________
Version: v2.0.0
Déployé par: _______________

---

# ✅ NOUVELLE : Checklist V2.1 - Monétisation + Stripe

## 🎯 Nouvelles fonctionnalités V2.1

- [x] Recherche textuelle (événement, groupe, photographe, pays)
- [x] Système de packs discount (3/5/10 photos)
- [x] Long-press pour sélection rapide
- [x] Precache d'images visibles
- [x] Intégration Stripe pour paiement
- [x] Affichage discount dans panier

## 📋 Étapes d'activation

### Phase 1 : Activation du code V2.1

- [ ] Activer media_shop_page_v21.dart
  ```bash
  bash /workspaces/MASLIVE/activate_shop_v21.sh
  ```

- [ ] Vérifier la compilation
  ```bash
  cd /workspaces/MASLIVE/app && flutter analyze
  ```

### Phase 2 : Configuration Stripe

- [ ] Récupérer clé Stripe Secret (sk_test_...)
- [ ] Déployer Cloud Functions
  ```bash
  bash /workspaces/MASLIVE/deploy_functions_stripe.sh
  ```

### Phase 3 : Déploiement

- [ ] Build web + déployer
  ```bash
  cd /workspaces/MASLIVE && firebase deploy --only hosting,functions
  ```

### Phase 4 : Tests

- [ ] Test recherche textuelle
- [ ] Test filtres en cascade
- [ ] Test long-press sur photos
- [ ] Test panier et discounts (3/5/10 photos)
- [ ] Test création commande
- [ ] Test paiement Stripe (carte 4242 4242 4242 4242)
- [ ] Vérifier commande "paid" en Firestore
- [ ] Vérifier purchases créées

## 📂 Fichiers V2.1

- [x] `app/lib/pages/media_shop_page_v21.dart` (1945 lignes)
- [x] `functions/index.js` - Callable Stripe
- [x] `functions/package.json` - Stripe SDK
- [x] `activate_shop_v21.sh` - Script d'activation
- [x] `deploy_functions_stripe.sh` - Script de déploiement
- [x] `V21_DEPLOYMENT.md` - Guide complet
- [x] `QUICK_STRIPE_DEPLOY.md` - Guide rapide
- [x] `STRIPE_SETUP.md` - Documentation Stripe

## 🎉 V2.1 déploiement prêt !

Version: v2.1.0  
Date: _______________  
Déployé par: _______________
