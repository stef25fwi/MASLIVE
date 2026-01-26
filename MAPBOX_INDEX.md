# 🗺️ MAPBOX CONFIGURATION - INDEX COMPLET

> Index centralisé pour la configuration du token Mapbox et les ressources associées

---

## ⭐ COMMENCER ICI

### 📖 Pour Démarrer Rapidement (5 minutes)
→ **Lire:** [MAPBOX_SETUP_QUICK.md](./MAPBOX_SETUP_QUICK.md)
→ **Exécuter:** `bash scripts/setup_mapbox.sh`

### 📚 Pour Comprendre Complètement
→ **Lire:** [MAPBOX_TOKEN_SETUP.md](./MAPBOX_TOKEN_SETUP.md)
→ **Référence:** [MAPBOX_CONFIGURATION.md](./MAPBOX_CONFIGURATION.md)

---

## 📋 TOUS LES FICHIERS CRÉÉS

### 🔐 Configuration
| Fichier | Description | Pour Qui |
|---------|-------------|----------|
| `.env.example` | Template des variables | Tous les développeurs |
| `.env` | Configuration locale (créée localement) | Développeur individuel |

### 📖 Documentation
| Fichier | Longueur | Contenu | Lire si... |
|---------|----------|---------|-----------|
| **MAPBOX_SETUP_QUICK.md** | ⭐ Court | Guide rapide 2-5 min | Vous êtes pressé |
| **MAPBOX_TOKEN_SETUP.md** | 📘 Moyen | Configuration détaillée | Vous voulez comprendre |
| **MAPBOX_CONFIGURATION.md** | 📗 Long | Guide complet + checklist | Vous configurer tout |
| **MAPBOX_CONFIG_SUMMARY.md** | 🏗️ Court | Vue d'ensemble | Aperçu rapide |
| **MAPBOX_DOCS_INDEX.md** | (existant) | Index doc ancienne | Référence historique |

### 🛠️ Scripts Exécutables
| Script | Fonction | Durée | Quand l'utiliser |
|--------|----------|-------|------------------|
| `scripts/setup_mapbox.sh` | Configuration interactive | 2 min | Première fois |
| `scripts/build_with_mapbox.sh` | Build web avec token | 3-5 min | Développement |
| `scripts/deploy_with_mapbox.sh` | Build + Firebase deploy | 8-10 min | Production |

### 🤖 CI/CD
| Fichier | CI/CD Platform | Status |
|---------|----------------|--------|
| `.github/workflows/build-deploy-mapbox.yml` | GitHub Actions | ✅ Prêt |

---

## 🚀 FLUX D'UTILISATION

### Workflow 1: Développeur Nouveau

```
1. Lire MAPBOX_SETUP_QUICK.md (2 min)
   ↓
2. Exécuter scripts/setup_mapbox.sh (2 min)
   ↓
3. Tester localement: flutter run -d chrome
   ↓
4. Prêt à développer! ✅
```

### Workflow 2: Build & Deploy

```
1. Configurer le token (si pas déjà fait)
   $ bash scripts/setup_mapbox.sh
   ↓
2. Builder + Déployer
   $ bash scripts/deploy_with_mapbox.sh
   ↓
3. Vérifier sur https://maslive.web.app ✅
```

### Workflow 3: GitHub Actions

```
1. Créer secret: Settings > Secrets > MAPBOX_PUBLIC_TOKEN
   ↓
2. Push sur main → GitHub Actions déclenche
   ↓
3. Build auto + Deploy auto ✅
   (voir .github/workflows/build-deploy-mapbox.yml)
```

---

## 🔑 OBTENIR LE TOKEN

**URL:** https://account.mapbox.com/tokens/

**Étapes:**
1. Connectez-vous (créez compte si besoin)
2. Allez à **Tokens** (menu gauche)
3. Cliquez **Create a token**
4. Donnez un nom: `MASLIVE_PUBLIC`
5. Copiez le token public (commence par `pk_`)

**Exemple de token:**
```
pk_eyJVIjoidGVzdDEyMzQ1Njc4OTAifQ.XyZ1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o
```

---

## 📍 PAGES UTILISANT MAPBOX

### POI Assistant Page
- **Fichier:** `app/lib/admin/poi_assistant_page.dart`
- **Où:** Étape 2 (Charger carte en plein écran)
- **Utilise:** `const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');`

### Circuit Assistant Page
- **Fichier:** `app/lib/admin/create_circuit_assistant_page.dart`
- **Où:** Affichage et édition circuits sur Mapbox
- **Utilise:** `const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');`

### Google Light Map Page
- **Fichier:** `app/lib/ui/google_light_map_page.dart`
- **Où:** Affichage personnalisé Mapbox
- **Utilise:** `const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');`

---

## 🧪 TESTS

### Test Local (Chrome)
```bash
export MAPBOX_PUBLIC_TOKEN="pk_your_token_here"
cd /workspaces/MASLIVE/app
flutter run -d chrome --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"
```

### Test Production
1. Ouvrez https://maslive.web.app
2. Admin Dashboard → POI Assistant (New)
3. Vérifiez que la carte Mapbox se charge (Étape 2)

---

## ✅ CHECKLIST

### Installation
- [ ] Lire MAPBOX_SETUP_QUICK.md
- [ ] Obtenir token sur mapbox.com
- [ ] Exécuter `bash scripts/setup_mapbox.sh`
- [ ] Vérifier `.env` créé

### Configuration
- [ ] `.env` dans `.gitignore` ✅
- [ ] Token valide (commence par `pk_`)
- [ ] Permissions scopes correctes sur mapbox.com
- [ ] Test local OK

### Déploiement
- [ ] Build OK: `bash scripts/build_with_mapbox.sh`
- [ ] Deploy OK: `bash scripts/deploy_with_mapbox.sh`
- [ ] Production OK: https://maslive.web.app fonctionne
- [ ] Cartes Mapbox visibles ✅

### GitHub Actions (Optionnel)
- [ ] Créer secret `MAPBOX_PUBLIC_TOKEN`
- [ ] Créer secret `FIREBASE_TOKEN` (si déploiement auto)
- [ ] Workflow déclenché sur push main ✅

---

## ❌ TROUBLESHOOTING RAPIDE

| Problème | Solution | Doc |
|----------|----------|-----|
| Token manquant | `bash scripts/setup_mapbox.sh` | MAPBOX_SETUP_QUICK.md |
| Carte blanche | Vérifier token valide sur mapbox.com | MAPBOX_TOKEN_SETUP.md |
| "Unauthorized" | Vérifier permissions token (scopes) | MAPBOX_CONFIGURATION.md |
| `.env` committée | `git rm --cached .env` | MAPBOX_TOKEN_SETUP.md |

---

## 🔗 RESSOURCES EXTERNES

- **Compte Mapbox:** https://account.mapbox.com
- **Tokens Mapbox:** https://account.mapbox.com/tokens/
- **Mapbox GL JS Docs:** https://docs.mapbox.com/mapbox-gl-js/
- **Mapbox API:** https://docs.mapbox.com/api/maps/

---

## 📞 STRUCTURE DES FICHIERS

```
/workspaces/MASLIVE/
│
├─ 📋 Configuration
│  ├─ .env                          ← LOCAL (pas committée) - Créer avec setup_mapbox.sh
│  ├─ .env.example                  ← TEMPLATE (à committer) ✅
│  └─ .gitignore                    ← Ignore .env ✅
│
├─ 📖 Documentation Mapbox
│  ├─ MAPBOX_SETUP_QUICK.md         ← ⭐ LIRE D'ABORD (5 min)
│  ├─ MAPBOX_TOKEN_SETUP.md         ← Configuration complète
│  ├─ MAPBOX_CONFIGURATION.md       ← Détails & checklist
│  ├─ MAPBOX_CONFIG_SUMMARY.md      ← Vue d'ensemble
│  ├─ MAPBOX_DOCS_INDEX.md          ← Index doc (ancien)
│  └─ MAPBOX_INDEX.md               ← CE FICHIER
│
├─ 🛠️ Scripts
│  └─ scripts/
│     ├─ setup_mapbox.sh            ← Configuration interactive
│     ├─ build_with_mapbox.sh       ← Build avec token
│     └─ deploy_with_mapbox.sh      ← Build + Deploy
│
├─ 🤖 CI/CD
│  └─ .github/workflows/
│     └─ build-deploy-mapbox.yml    ← GitHub Actions
│
└─ 🔍 Code Pages (utilisant Mapbox)
   └─ app/lib/
      ├─ admin/
      │  ├─ poi_assistant_page.dart
      │  └─ create_circuit_assistant_page.dart
      └─ ui/
         └─ google_light_map_page.dart
```

---

## 🎯 RÉSUMÉ POUR LES IMPATIENTS

**5 minutes pour tout intégrer:**

```bash
# 1. Configuration (2 min)
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh

# 2. Build + Deploy (3 min)
bash /workspaces/MASLIVE/scripts/deploy_with_mapbox.sh

# 3. ✅ Vérifier sur https://maslive.web.app
```

---

**Statut:** ✅ Configuration Complète  
**Dernière mise à jour:** 2026-01-26  
**Pages impactées:** 3 (POI Assistant, Circuit Assistant, Google Light Map)
