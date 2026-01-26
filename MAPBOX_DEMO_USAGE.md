# 🎬 MAPBOX - DÉMONSTRATION & UTILISATION

> Guide pratique d'utilisation complète de la configuration Mapbox

---

## 🎯 Scénarios d'Utilisation

### Scénario 1️⃣ : Premier Déploiement (Nouveau Projet)

**Situation:** Vous avez cloné le repo MASLIVE, Mapbox n'est pas configuré

**Étapes:**

```bash
# 1. Aller à la racine du projet
cd /workspaces/MASLIVE

# 2. Lancer la configuration interactive
bash scripts/setup_mapbox.sh

# ✅ Suivre les instructions:
#    - Obtenir token sur mapbox.com
#    - Coller le token (pk_...)
#    - Laisser le script créer .env
#    - Optionnel: tester le build

# 3. Vérifier que .env est créé
cat .env
# Résultat: MAPBOX_PUBLIC_TOKEN=pk_...

# 4. ✅ Configuration terminée!
```

**Temps:** ~5 minutes

---

### Scénario 2️⃣ : Build Local pour Développement

**Situation:** Vous avez configuré Mapbox, vous voulez tester localement

**Option A: Utiliser le script**

```bash
# Configuration interactive
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh

# Puis le script vous propose de builder
```

**Option B: Build manuel**

```bash
# Charger le token depuis .env
source /workspaces/MASLIVE/.env

# Aller dans le dossier app
cd /workspaces/MASLIVE/app

# Builder avec le token
flutter pub get
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"

# Résultat: build/web/ est prêt
echo "✅ Build disponible dans: build/web/"
```

**Temps:** ~10 minutes (premier build plus long)

---

### Scénario 3️⃣ : Deploy Production (Firebase Hosting)

**Situation:** Vous avez builté localement, vous voulez mettre en production

**Option A: Utiliser le script (recommandé)**

```bash
# All-in-one: build + deploy
bash /workspaces/MASLIVE/scripts/deploy_with_mapbox.sh

# Le script va:
# 1. Charger .env
# 2. Builder web avec token Mapbox
# 3. Déployer vers Firebase Hosting
# 4. Afficher l'URL finale

# Résultat: https://maslive.web.app
```

**Option B: Manuel étape par étape**

```bash
# 1. Charger le token
source /workspaces/MASLIVE/.env

# 2. Builder
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"

# 3. Déployer
cd ..
firebase deploy --only hosting

# 4. ✅ Vérifier sur https://maslive.web.app
```

**Temps:** ~15 minutes

---

### Scénario 4️⃣ : Intégration GitHub Actions (CI/CD)

**Situation:** Vous voulez que chaque push auto-déclenche build + deploy

**Étapes:**

```bash
# 1. Créer secret GitHub
#    a. Allez à Settings > Secrets and variables > Actions
#    b. Click "New repository secret"
#    c. Nom: MAPBOX_PUBLIC_TOKEN
#    d. Valeur: pk_your_token_here

# 2. Créer secret Firebase (optionnel, si deploy auto)
#    Même process, mais:
#    Nom: FIREBASE_TOKEN
#    Valeur: (générer via: firebase login:ci)

# 3. Puis chaque push automatiquement:
#    git push origin main
#    ↓
#    GitHub Actions déclenche
#    ↓
#    Build avec Mapbox token
#    ↓
#    Deploy sur Firebase
#    ↓
#    ✅ Auto-déployé!

# 4. Vérifier le workflow
#    Allez à Actions tab dans GitHub
#    Vérifiez que "Build & Deploy Flutter Web with Mapbox" a réussi
```

**Temps:** ~10 minutes (setup unique)

**Après:** Chaque push = auto-deploy (5 min)

---

### Scénario 5️⃣ : Test en Local Avant Deploy

**Situation:** Vous voulez tester les cartes Mapbox avant de pousser

```bash
# 1. Configurer token
export MAPBOX_PUBLIC_TOKEN="pk_your_token_here"

# 2. Build web (rapide)
cd /workspaces/MASLIVE/app
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"

# 3. Tester localement
#    Option A: Ouvrir build/web/index.html dans navigateur
open build/web/index.html

#    Option B: Servir avec un serveur HTTP
cd build/web
python3 -m http.server 8000
# Puis ouvrir http://localhost:8000

# 4. Vérifier fonctionnalités Mapbox:
#    - Admin Dashboard
#    - POI Assistant (New)
#    - Étape 2: Carte Mapbox fullscreen
#    - Étape 3: Sélectionner couche
#    - Étape 4: Ajouter/éditer POIs

# 5. Si tout OK, commit et push
git add .
git commit -m "feature: mapbox integration working"
git push origin main
```

**Temps:** ~20 minutes

---

### Scénario 6️⃣ : Troubleshooting - Carte Blanche

**Situation:** La carte ne s'affiche pas (écran blanc)

```bash
# 1. Vérifier que .env existe
ls -la /workspaces/MASLIVE/.env
# Résultat: -rw-r--r-- 1 vscode vscode ... .env

# 2. Vérifier le contenu
cat /workspaces/MASLIVE/.env
# Résultat: MAPBOX_PUBLIC_TOKEN=pk_...

# 3. Vérifier format du token
grep MAPBOX_PUBLIC_TOKEN /workspaces/MASLIVE/.env | cut -d= -f2 | head -c 10
# Résultat: pk_ ... (commence par pk_ ✅)

# 4. Vérifier le token est valide sur mapbox.com
#    Allez à https://account.mapbox.com/tokens/
#    Trouvez le token
#    Vérifiez qu'il n'est pas "disabled"

# 5. Vérifier les permissions
#    Settings > Token info
#    Scopes:
#    - Maps: Manage resources ✅
#    - Styles: Read ✅

# 6. Forcer rebuild clean
cd /workspaces/MASLIVE/app
rm -rf build/
flutter clean
flutter pub get

# 7. Rebuild avec token explicite
source /workspaces/MASLIVE/.env
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"

# 8. Tester
# Ouvrir build/web/index.html ou déployer
```

**Temps:** ~10 minutes

---

## 🔄 Cycles de Déploiement

### Cycle Court (Développement)

```
1. Modifier code (.dart)
2. Build local: flutter run -d chrome
3. Tester
4. Commit: git add . && git commit -m "..."
5. Push: git push origin main
6. GitHub Actions auto-déclenche
7. ✅ Auto-deployed en ~5 minutes
```

### Cycle Long (Production)

```
1. Préparation (tout prêt)
2. Build complet: bash scripts/deploy_with_mapbox.sh
3. Tester sur staging/production
4. Valider
5. Commit: git add . && git commit -m "release: v1.0"
6. Tag: git tag v1.0 && git push --tags
7. ✅ Déployé en production
```

---

## 📊 Commandes Rapides

### Setup & Configuration

```bash
# Configuration interactive (première fois)
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh

# Voir le token configuré
cat /workspaces/MASLIVE/.env
```

### Build & Test

```bash
# Build web avec Mapbox
bash /workspaces/MASLIVE/scripts/build_with_mapbox.sh

# Tester localement
flutter run -d chrome --dart-define=MAPBOX_ACCESS_TOKEN="pk_..."

# Vérifier build size
du -sh /workspaces/MASLIVE/app/build/web
```

### Deploy

```bash
# Build + Deploy complet
bash /workspaces/MASLIVE/scripts/deploy_with_mapbox.sh

# Ou manuellement
source /workspaces/MASLIVE/.env
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"
cd ..
firebase deploy --only hosting
```

### Maintenance

```bash
# Renouveler token (ancien expiré)
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh

# Vérifier token valide
grep MAPBOX_PUBLIC_TOKEN /workspaces/MASLIVE/.env

# Nettoyer builds anciens
rm -rf /workspaces/MASLIVE/app/build/
flutter clean
```

---

## ✅ Checklist par Rôle

### 👨‍💻 Développeur Nouveau

- [ ] Lire MAPBOX_SETUP_QUICK.md
- [ ] `bash scripts/setup_mapbox.sh`
- [ ] Tester: `flutter run -d chrome`
- [ ] Vérifier que POI Assistant fonctionne

### 🚀 DevOps / Release Manager

- [ ] Vérifier secrets GitHub (MAPBOX_PUBLIC_TOKEN, FIREBASE_TOKEN)
- [ ] Vérifier workflow GitHub Actions fonctionne
- [ ] Tester deploy: `bash scripts/deploy_with_mapbox.sh`
- [ ] Vérifier production: https://maslive.web.app

### 🔍 QA / Testeur

- [ ] Tester POI Assistant (Étape 2 - Mapbox)
- [ ] Tester Circuit Assistant (Mapbox)
- [ ] Vérifier que cartes se chargent
- [ ] Vérifier que interactif (zoom, pan)

### 🏗️ Architecte / Lead Dev

- [ ] Vérifier sécurité (.env pas committée)
- [ ] Vérifier CI/CD pipeline fonctionne
- [ ] Planifier rotation token
- [ ] Documenter pour l'équipe

---

## 🎓 Exemples Pas à Pas

### Exemple 1: Premier Déploiement

```bash
# Jour 1 - Setup
$ cd /workspaces/MASLIVE
$ bash scripts/setup_mapbox.sh
# ✅ Token configuré dans .env

# Jour 2 - Deploy
$ bash scripts/deploy_with_mapbox.sh
# ✅ Application deployée sur https://maslive.web.app

# Jour 3 - Vérification
$ # Ouvrir https://maslive.web.app
$ # Admin Dashboard > POI Assistant
$ # Vérifier que Mapbox charge correctement
$ # ✅ Succès!
```

### Exemple 2: Avec Équipe (GitHub Actions)

```bash
# Semaine 1 - Setup CI/CD
1. Créer secret GitHub: MAPBOX_PUBLIC_TOKEN
2. Vérifier workflow: .github/workflows/build-deploy-mapbox.yml
3. Test: git push origin main
4. ✅ Auto-déployé!

# Semaine 2 - Chaque développeur
git clone repo
bash scripts/setup_mapbox.sh
# (chacun avec son token personnel pour dev local)

git add feature/mapbox-improvements
git commit -m "..."
git push origin feature-branch
# ✅ GitHub Actions valide + déploie branche

git push origin main
# ✅ GitHub Actions déploie en production
```

---

## 📖 Référence Rapide

| Besoin | Commande | Doc |
|--------|----------|-----|
| Première setup | `bash scripts/setup_mapbox.sh` | MAPBOX_SETUP_QUICK.md |
| Build local | `bash scripts/build_with_mapbox.sh` | MAPBOX_CONFIGURATION.md |
| Deploy prod | `bash scripts/deploy_with_mapbox.sh` | MAPBOX_TOKEN_SETUP.md |
| Debug | Voir TROUBLESHOOTING | MAPBOX_TOKEN_SETUP.md |
| GitHub Actions | Voir `.github/workflows/` | .github/workflows/build-deploy-mapbox.yml |

---

**Dernière mise à jour:** 2026-01-26  
**Status:** ✅ Prêt pour Production
