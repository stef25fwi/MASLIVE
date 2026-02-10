# 🚀 Guide de Déploiement MASLIVE

## État Actuel

✅ **Branche**: `copilot/fix-stock-validation-client-side`  
✅ **Statut**: Tous les changements sont committés et pushés  
✅ **Dernière modification**: Corrections boutique (validation stock, gestion erreurs paiement, page commandes)  
✅ **Script de déploiement**: `push_commit_build_deploy.sh` prêt

## 📋 Options de Déploiement

### Option 1: Déploiement Automatique via GitHub Actions ⭐ RECOMMANDÉ

Le repository a déjà un workflow GitHub Actions configuré (`.github/workflows/build-deploy-mapbox.yml`) qui se déclenche automatiquement sur les pushs vers `main`.

**Étapes:**

1. **Merger la branche vers main** (via Pull Request ou directement):
   ```bash
   # Via GitHub UI: Créer et merger le Pull Request
   # OU en ligne de commande:
   git checkout main
   git pull origin main
   git merge copilot/fix-stock-validation-client-side
   git push origin main
   ```

2. **Le workflow GitHub Actions se déclenchera automatiquement** et exécutera:
   - Checkout du code
   - Installation Flutter (v3.24.0)
   - Installation des dépendances
   - Build Flutter Web avec token Mapbox
   - *Note: Le workflow actuel build seulement, pas de déploiement Firebase*

### Option 2: Déploiement Manuel Local

Si vous avez Flutter SDK et Firebase CLI installés localement:

```bash
# 1. Récupérer la branche
git checkout copilot/fix-stock-validation-client-side
git pull origin copilot/fix-stock-validation-client-side

# 2. Exécuter le script de déploiement
./push_commit_build_deploy.sh "deploy: corrections boutique"
```

Le script effectuera:
- ✅ Vérifications de sécurité (pas de secrets)
- ✅ Nettoyage des fichiers temporaires
- ✅ Commit et push des changements
- ✅ Build Flutter web (release)
- ✅ Déploiement Firebase (hosting + functions + rules)

### Option 3: Déploiement Firebase Direct

Si vous voulez déployer uniquement Firebase sans rebuild:

```bash
# Déploiement complet
firebase deploy

# Déploiement hosting uniquement
firebase deploy --only hosting

# Déploiement functions uniquement
firebase deploy --only functions

# Déploiement rules uniquement
firebase deploy --only firestore:rules,firestore:indexes
```

## 🔧 Prérequis pour Déploiement Local

### Flutter SDK
```bash
# Vérifier installation
flutter --version

# Si non installé: https://flutter.dev/docs/get-started/install
```

### Firebase CLI
```bash
# Vérifier installation
firebase --version

# Installation
npm install -g firebase-tools

# Login
firebase login
```

### Node.js (pour Functions)
```bash
# Vérifier installation
node --version
npm --version
```

## 📝 Ce Qui Sera Déployé

Les derniers changements incluent:

1. **Validation Stock Côté Client** (`product_detail_page.dart`)
   - Vérification stricte du stock avant ajout au panier
   - Messages d'erreur clairs

2. **Gestion Erreurs Paiement** (`cart_page.dart`)
   - Gestion complète des erreurs Firebase Functions
   - Retry logic avec re-authentification
   - Messages d'erreur détaillés

3. **Page "Mes Commandes"** (`my_orders_page.dart`)
   - Nouvelle page pour visualiser les commandes utilisateur
   - Affichage en temps réel depuis Firestore
   - Statuts colorés et détails des commandes

4. **Validation Stock CartService** (`cart_service.dart`)
   - Méthode `validateStock()` avec vérification Firestore
   - Validation automatique avant checkout

5. **Tests Unitaires** (`cart_service_test.dart`)
   - 7 tests pour CartService
   - Couverture complète des fonctions

6. **Helpers et Améliorations**
   - Helper `variantKey` dans `cart_item.dart`
   - Helper `_showErrorWithRetry()` dans `cart_page.dart`
   - Documentation améliorée

## 🔒 Vérifications de Sécurité

Avant déploiement, le script vérifie que ces fichiers ne sont PAS committés:
- ❌ `functions/node_modules/`
- ❌ `serviceAccountKey.json`
- ❌ `*firebase-adminsdk*.json`
- ❌ `functions/.env*`
- ❌ `functions/.runtimeconfig.json`

## ⚠️ Important

1. **Variables d'environnement**: Assurez-vous que les secrets Firebase et Mapbox sont configurés
2. **Backup**: Faites un backup de Firestore avant de déployer les nouvelles rules
3. **Test**: Testez les nouvelles fonctionnalités sur un environnement de staging si disponible

## 🎯 Déploiement Recommandé

**Pour déploiement en production:**

1. ✅ Créer un Pull Request de `copilot/fix-stock-validation-client-side` vers `main`
2. ✅ Review du code par l'équipe
3. ✅ Tests des nouvelles fonctionnalités
4. ✅ Merger le PR
5. ✅ Le workflow GitHub Actions se déclenche automatiquement
6. ✅ (Optionnel) Déploiement Firebase manuel si GitHub Actions ne le fait pas

## 📞 Support

En cas de problème:
- Vérifier les logs GitHub Actions
- Vérifier les logs Firebase (`firebase functions:log`)
- Consulter la documentation: `PUSH_COMMIT_BUILD_DEPLOY.md`

---

**Date**: 2026-02-10  
**Branche**: copilot/fix-stock-validation-client-side  
**Status**: ✅ Prêt pour déploiement
