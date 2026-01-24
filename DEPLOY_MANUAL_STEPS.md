# 🚀 Commandes de déploiement - Exécution manuelle

Le terminal a rencontré des problèmes de permissions. Voici les commandes à exécuter manuellement pour finaliser le déploiement.

## 📋 Résumé des changements

### Fichiers modifiés (3)
- `app/lib/pages/home_map_page.dart` - Animation menu navigation
- `app/lib/admin/admin_main_dashboard.dart` - Dashboard admin réorganisé
- `functions/index.js` - (changements antérieurs webhook Stripe)

### Fichiers créés/ajoutés (3)
- `ADMIN_DASHBOARD_STRUCTURE.md` - Documentation dashboard
- `STRIPE_WEBHOOK_SETUP.md` - Guide configuration webhooks
- `DEPLOYMENT_STATUS_20260124.md` - Rapport statut déploiement

---

## 🔄 Étape 1 : Commit

```bash
cd /workspaces/MASLIVE

# Ajouter tous les fichiers
git add -A

# Vérifier le statut
git status

# Créer le commit
git commit -m "feat: animation menu navigation + dashboard admin réorganisé + section comptes pro

- Ajouter animation de glissement (slide transition) pour fermer la barre de navigation verticale avant navigation vers Compte/Shop
- Réorganiser le dashboard administrateur avec 6 sections claires :
  * Carte & Navigation (circuits, POIs)
  * Tracking & Groupes (suivi live, groupes)
  * Commerce (produits, commandes, Stripe)
  * Utilisateurs (gestion rôles)
  * Comptes Professionnels (demandes pro - NEW)
  * Analytics & Système (stats, logs, config)
- Ajouter tuile 'Demandes Pro' dans section Comptes Professionnels
- Ajouter documentation ADMIN_DASHBOARD_STRUCTURE.md
- Ajouter guide configuration webhook Stripe (STRIPE_WEBHOOK_SETUP.md)
- Ajouter rapport statut déploiement (DEPLOYMENT_STATUS_20260124.md)"
```

---

## 📤 Étape 2 : Push

```bash
# Vérifier la branche actuelle
git branch

# Pusher vers origin/main
git push origin main

# Ou si main est protégée, créer une feature branch:
# git checkout -b feature/admin-dashboard-menu-animation
# git push origin feature/admin-dashboard-menu-animation
```

---

## 🔨 Étape 3 : Build Flutter

```bash
cd /workspaces/MASLIVE/app

# Nettoyer les builds antérieurs
flutter clean

# Télécharger les dépendances
flutter pub get

# Builder pour web (release)
flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://www.gstatic.com/flutter-canvaskit/

# Retour au répertoire racine
cd ..
```

**Durée estimée** : 2-5 minutes

---

## 🌐 Étape 4 : Déployer sur Firebase

```bash
# Déployer Hosting + Functions + Rules + Indexes
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes

# Ou déployer chaque composant séparément :

# Uniquement hosting
firebase deploy --only hosting

# Uniquement functions
firebase deploy --only functions

# Uniquement Firestore rules
firebase deploy --only firestore:rules

# Uniquement Firestore indexes
firebase deploy --only firestore:indexes
```

**Durée estimée** : 3-10 minutes

---

## ✅ Vérification post-déploiement

```bash
# 1. Vérifier le dernier commit
git log -1 --oneline

# 2. Vérifier les logs functions
firebase functions:log

# 3. Vérifier l'URL live
echo "App live: https://maslive.web.app"

# 4. Ouvrir le dashboard Firebase
open "https://console.firebase.google.com/project/maslive"
```

---

## 🎯 Résumé des nouvelles fonctionnalités

### 1️⃣ Animation Menu Navigation
**Fichier** : `app/lib/pages/home_map_page.dart`

- Animation de glissement fluide avant navigation vers Compte/Shop
- Appliquée aux actions : Account, Login, Shop
- Délai de 500ms pour laisser le temps à l'animation

### 2️⃣ Dashboard Admin Réorganisé
**Fichier** : `app/lib/admin/admin_main_dashboard.dart`

**Nouvelles sections** :
1. **Carte & Navigation** - Circuits + POIs
2. **Tracking & Groupes** - Suivi live + Groupes
3. **Commerce** - Produits + Commandes + Test Stripe
4. **Utilisateurs** - Gestion rôles
5. **Comptes Professionnels** ✨ - **Demandes Pro (NEW)**
6. **Analytics & Système** - Stats + Logs + Config

**Accès** : Menu Compte → Espace Admin → Dashboard

### 3️⃣ Tuile "Demandes Pro"
- Navigation vers `BusinessRequestsPage`
- Icône : `Icons.request_page`
- Couleur : Saumon (Orange foncé)
- Permet aux admins de valider/rejeter les demandes de comptes professionnels Stripe

---

## 📊 État du déploiement

### Avant ce commit
- ✅ Webhook Stripe implémenté (endpoint HTTP sécurisé)
- ✅ Cloud Functions réduites à 0.083 vCPU (problème quota résolu)
- ⚠️ 12/13 functions déployées (assignUserCategory timeout, redeployé avec succès)

### Après ce commit
- ✅ Menu navigation avec animation fluide
- ✅ Dashboard admin complètement réorganisé
- ✅ Section "Comptes Professionnels" avec tuile "Demandes Pro"
- ✅ Documentation complète

---

## 🐛 Troubleshooting

### Erreur "main is a protected branch"
```bash
# Créer une feature branch à la place
git checkout -b feature/admin-dashboard-menu-animation
git push origin feature/admin-dashboard-menu-animation
# Puis créer une PR
```

### Erreur "403 Forbidden" au push
```bash
# Vérifier l'authentification
gcloud auth application-default login
firebase login

# Retenter le push
git push origin main
```

### Build web échoue
```bash
# Nettoyer et recommencer
flutter clean
rm -rf build/
flutter pub cache repair
flutter pub get
flutter build web --release
```

### Firebase deploy échoue
```bash
# Vérifier l'authentification
firebase login

# Vérifier la région
firebase functions:list

# Déployer avec plus de détails
firebase deploy --debug
```

---

## 📝 Prochaines étapes

1. ✅ Exécuter les commandes ci-dessus dans l'ordre
2. ⏳ Attendre le build et le déploiement
3. 🧪 Tester l'animation du menu sur `/` (home map)
4. 🧪 Tester le dashboard admin depuis le menu Compte
5. 🧪 Vérifier que la tuile "Demandes Pro" navigue correctement
6. 🔗 Vérifier le webhook Stripe (configuration du secret + URL dans dashboard Stripe)

---

## 🚀 Commande rapide (copier-coller)

```bash
cd /workspaces/MASLIVE && \
git add -A && \
git commit -m "feat: animation menu navigation + dashboard admin réorganisé" && \
git push origin main && \
cd app && \
flutter clean && flutter pub get && flutter build web --release && \
cd .. && \
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes
```

---

## 📞 Support

En cas de problème :
1. Vérifier les logs : `firebase functions:log`
2. Vérifier le dashboard : https://console.firebase.google.com/project/maslive
3. Consulter les fichiers de documentation générés
