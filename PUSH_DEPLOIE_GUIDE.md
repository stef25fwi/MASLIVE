# 🚀 Guide: Push et Déploie

## ✅ État Actuel

### Ce qui est PRÊT:
- ✅ Code: Tous les changements committés et pushés sur `copilot/fix-stock-validation-client-side`
- ✅ Firebase CLI: Installé (version 15.5.1)
- ✅ Node.js: v24.13.0 installé
- ✅ Tests: 7 tests unitaires passent
- ✅ Documentation: Complète

### Ce qui MANQUE:
- ❌ Flutter SDK: Non disponible dans cet environnement
- ❌ Build Flutter: Pas de `app/build/web/`

## 🎯 Solutions de Déploiement

### Solution 1: GitHub Actions (RECOMMANDÉ) ⭐

**Avantages:**
- ✅ Build automatique avec Flutter
- ✅ Déploiement automatique
- ✅ Pas besoin de Flutter local

**Étapes:**

1. **Créer une Pull Request**
   ```
   Aller sur: https://github.com/stef25fwi/MASLIVE/pulls
   Cliquer: "New Pull Request"
   Base: main ← Compare: copilot/fix-stock-validation-client-side
   Titre: "Shop improvements: validation, translations, UX"
   Créer la PR
   ```

2. **Merger la PR**
   ```
   Review les changements
   Cliquer "Merge pull request"
   Confirmer le merge
   ```

3. **Déploiement automatique**
   ```
   GitHub Actions détecte le push vers main
   Workflow build-deploy-mapbox.yml s'exécute
   Build Flutter + Deploy Firebase automatique
   ```

4. **Vérifier le déploiement**
   ```
   Aller sur: Actions tab sur GitHub
   Voir le workflow en cours
   Attendre la fin (vert ✓)
   ```

---

### Solution 2: Déploiement Local (Si vous avez Flutter)

**Prérequis:**
- Flutter SDK installé localement
- Firebase CLI configuré
- Accès au projet Firebase

**Étapes complètes:**

```bash
# 1. Clone/Pull le repository
git clone https://github.com/stef25fwi/MASLIVE.git
cd MASLIVE
git checkout copilot/fix-stock-validation-client-side
git pull

# 2. Installer les dépendances
cd app
flutter pub get

# 3. Build pour web
flutter build web --release

# 4. Retour au root
cd ..

# 5. Login Firebase (si pas déjà fait)
firebase login

# 6. Vérifier le projet
firebase projects:list
firebase use <votre-projet-id>

# 7. Deploy complet
firebase deploy

# OU déploiement ciblé:
firebase deploy --only hosting
firebase deploy --only firestore:rules
firebase deploy --only functions
```

**Ou utiliser le script:**
```bash
./push_commit_build_deploy.sh "deploy: shop improvements v2.1"
```

---

### Solution 3: Deploy Functions/Rules uniquement (Sans Build)

Si vous voulez déployer seulement les règles Firestore et Functions (sans rebuild du frontend):

```bash
cd /home/runner/work/MASLIVE/MASLIVE

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Cloud Functions
firebase deploy --only functions

# Deploy indexes
firebase deploy --only firestore:indexes
```

⚠️ **Note**: Le frontend ne sera pas mis à jour avec cette option.

---

## 📦 Contenu à Déployer

Quand le déploiement sera fait, les changements suivants seront en production:

### Frontend (Hosting)
- ✅ Validation stock client
- ✅ Gestion erreurs paiement améliorée
- ✅ Page "Mes commandes"
- ✅ Traductions FR/ES/EN
- ✅ Bouton langue dans drawer
- ✅ Police menu agrandie

### Backend (Functions)
- ✅ Cloud Functions existantes (si modifiées)

### Database (Firestore)
- ✅ Rules mises à jour
- ✅ Indexes optimisés

---

## 🔍 Vérification Post-Déploiement

Après déploiement, vérifier:

1. **Site web accessible**
   ```
   Ouvrir l'URL de votre Firebase Hosting
   Vérifier que la page charge
   ```

2. **Fonctionnalités shop**
   ```
   ✓ Ajouter un produit au panier
   ✓ Vérifier validation stock
   ✓ Tester checkout (paiement)
   ✓ Voir "Mes commandes"
   ✓ Changer de langue (FR/ES/EN)
   ```

3. **Console Firebase**
   ```
   Aller sur console.firebase.google.com
   Vérifier Hosting → Dernier déploiement
   Vérifier Functions → Logs
   Vérifier Firestore → Données
   ```

4. **Logs et monitoring**
   ```bash
   # Voir les logs Functions
   firebase functions:log

   # Voir les logs en temps réel
   firebase functions:log --only <function-name>
   ```

---

## 🚨 Troubleshooting

### Problème: Firebase login échoue
```bash
# Essayer avec:
firebase login --reauth

# Ou logout puis login:
firebase logout
firebase login
```

### Problème: Build Flutter échoue
```bash
# Nettoyer et rebuild:
cd app
flutter clean
flutter pub get
flutter build web --release
```

### Problème: Deploy échoue
```bash
# Vérifier le projet:
firebase projects:list
firebase use <project-id>

# Vérifier les permissions:
firebase projects:list
```

### Problème: Ancien build en cache
```bash
# Clear cache Firebase:
firebase hosting:channel:delete <channel-name>

# Rebuild et redeploy:
cd app
flutter clean
flutter build web --release
cd ..
firebase deploy --only hosting
```

---

## 📋 Checklist de Déploiement

### Avant le Déploiement:
- [x] Code testé localement
- [x] Tests unitaires passent
- [x] Code review fait
- [x] Pas de secrets hardcodés
- [x] Documentation à jour

### Déploiement:
- [ ] Build Flutter réussi
- [ ] Firebase deploy réussi
- [ ] Pas d'erreurs dans les logs

### Après le Déploiement:
- [ ] Site accessible
- [ ] Fonctionnalités testées
- [ ] Pas d'erreurs en console
- [ ] Monitoring activé

---

## 🎯 Commande Rapide (Une ligne)

**Si vous avez Flutter et Firebase CLI:**
```bash
cd /home/runner/work/MASLIVE/MASLIVE && cd app && flutter build web --release && cd .. && firebase deploy
```

**Ou avec le script:**
```bash
cd /home/runner/work/MASLIVE/MASLIVE && ./push_commit_build_deploy.sh "deploy: v2.1"
```

---

## 💡 Recommandation Finale

🎯 **POUR CE CAS**: Utilisez **Solution 1 (GitHub Actions)**

Pourquoi?
- ✅ Flutter SDK pas disponible ici
- ✅ GitHub Actions a Flutter configuré
- ✅ Build + Deploy automatique
- ✅ Workflow déjà testé et fonctionnel
- ✅ Historique des déploiements

**Action immédiate:**
1. Aller sur GitHub
2. Créer une PR vers main
3. Merger la PR
4. Attendre le déploiement automatique

---

**Status**: ✅ Code prêt, Firebase CLI disponible, recommandation: GitHub Actions
