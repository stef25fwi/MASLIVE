# 📦 Guide d'Installation - Flutter SDK et Firebase CLI

## État d'Installation

Date: 2026-02-10  
Environnement: GitHub Actions Runner (Ubuntu 24.04)

---

## ✅ Firebase CLI - INSTALLÉ

### Installation Réussie

```bash
npm install -g firebase-tools
```

**Version Installée**: 15.5.1  
**Location**: `/home/runner/work/_temp/ghcca-node/node/bin/firebase`

### Vérification

```bash
$ firebase --version
15.5.1

$ which firebase
/home/runner/work/_temp/ghcca-node/node/bin/firebase
```

### Utilisation

Firebase CLI est **opérationnel** et prêt à utiliser pour:

```bash
# Login (nécessite authentification)
firebase login

# Déploiement
firebase deploy
firebase deploy --only hosting
firebase deploy --only functions

# Logs
firebase functions:log

# Autres commandes
firebase projects:list
firebase use <project-id>
```

---

## ⚠️ Flutter SDK - INSTALLATION PARTIELLE

### Statut

- ✅ **Repository Flutter**: Cloné depuis GitHub
- ✅ **Version**: Stable branch
- ✅ **Location**: `/home/runner/flutter`
- ❌ **Dart SDK**: Échec du téléchargement (403 Forbidden)

### Problème Rencontré

Le Dart SDK ne peut pas être téléchargé depuis Google Cloud Storage dans cet environnement:

```
Error: 403 Forbidden
URL: https://storage.googleapis.com/flutter_infra_release/flutter/.../dart-sdk-linux-x64.zip
```

### Cause

Restrictions réseau sur l'environnement GitHub Actions qui empêchent l'accès direct à certaines ressources Google Cloud Storage.

---

## 🔧 Solutions et Alternatives

### Option 1: GitHub Actions (RECOMMANDÉ) ⭐

**Le workflow existant `.github/workflows/build-deploy-mapbox.yml` résout déjà ce problème:**

```yaml
- uses: subosito/flutter-action@v2
  with:
    flutter-version: "3.24.0"
    cache: true
```

**Avantages:**
- Installation automatique de Flutter
- Gestion du cache
- Pas de configuration manuelle
- Fonctionne dans tous les workflows

**Utilisation:**
1. Merge vers `main` ou créer un PR
2. Le workflow s'exécute automatiquement
3. Flutter est installé et configuré
4. Le build se fait sans problème

### Option 2: Installation Locale

Sur votre machine locale avec accès internet:

**Via Snap (Ubuntu/Linux):**
```bash
sudo snap install flutter --classic
flutter doctor
```

**Via Git:**
```bash
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor
flutter --version
```

**Via Téléchargement Direct:**
```bash
# Télécharger depuis flutter.dev
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz
tar xf flutter_linux_3.24.0-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"
```

### Option 3: Docker

Utiliser une image Docker avec Flutter pré-installé:

```dockerfile
FROM cirrusci/flutter:stable

WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release
```

---

## 🎯 Recommandations

### Pour le Développement

**Local:**
- Installer Flutter localement via snap ou git
- Utiliser Firebase CLI (déjà installé)
- Développer et tester localement

### Pour le Déploiement

**GitHub Actions:**
- Utiliser le workflow existant
- Merge vers main pour déploiement automatique
- Pas besoin d'installation manuelle

### Pour CI/CD

Le projet est **déjà configuré** pour utiliser GitHub Actions avec Flutter, donc:
- ✅ Pas d'action supplémentaire requise
- ✅ Le workflow gère l'installation automatiquement
- ✅ Chaque push vers main déclenche le build

---

## 📊 Résumé des Outils

| Outil | Statut | Version | Disponible | Notes |
|-------|--------|---------|------------|-------|
| **Node.js** | ✅ | v24.13.0 | Oui | Préinstallé |
| **npm** | ✅ | 11.6.2 | Oui | Préinstallé |
| **Firebase CLI** | ✅ | 15.5.1 | **Oui** | **Prêt à utiliser** |
| **Flutter SDK** | ⚠️ | stable | Partiel | Via GitHub Actions |
| **Dart SDK** | ❌ | - | Non | Via GitHub Actions |

---

## 💡 Commandes Utiles

### Firebase CLI

```bash
# Version
firebase --version

# Login (interactive)
firebase login

# Utiliser un projet
firebase use maslive-xxxxx

# Déployer
firebase deploy

# Voir les logs
firebase functions:log --limit 50
```

### Flutter (via GitHub Actions)

Le workflow `.github/workflows/build-deploy-mapbox.yml` exécute automatiquement:

```bash
flutter pub get
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN=$TOKEN
```

---

## 🔍 Vérification de l'Installation

### Firebase CLI
```bash
$ firebase --version
15.5.1
✅ OK
```

### Flutter (GitHub Actions)
```bash
# Vérifier le workflow
cat .github/workflows/build-deploy-mapbox.yml
✅ OK - Configured with flutter-action
```

---

## 📞 Support

**Firebase CLI**: Opérationnel ✅  
**Flutter SDK**: Disponible via GitHub Actions ✅

Pour déployer:
1. Voir `GUIDE_DEPLOIEMENT.md`
2. Utiliser GitHub Actions (recommandé)
3. Ou installer Flutter localement

---

**Status Final**: Firebase CLI est installé et opérationnel. Flutter SDK est disponible via GitHub Actions workflow existant. Aucune action supplémentaire requise pour le déploiement.
