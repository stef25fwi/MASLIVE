# 🚀 Quick Start - Gestion Articles Superadmin

## ⏱️ TL;DR (3 minutes)

### 1. Déployer (2 minutes)
```bash
cd /workspaces/MASLIVE

# Commit
git add . && git commit -m "feat: gestion articles superadmin" && git push origin main

# Deploy
firebase deploy --only functions,firestore:rules
cd app && flutter build web --release && cd ..
firebase deploy --only hosting
```

### 2. Initialiser (30 secondes)
```bash
firebase functions:shell
> initSuperadminArticles()
# ✅ { success: true, created: 4 }
```

### 3. Tester (30 secondes)
- Se connecter superadmin
- Aller Profil → Commerce → "Mes articles en ligne"
- Voir 4 articles
- ✅ Fait!

---

## 📋 Fichiers importants

| Fichier | Lignes | Rôle |
|---------|--------|------|
| `superadmin_article.dart` | 130 | Modèle |
| `superadmin_article_service.dart` | 185 | Service |
| `superadmin_articles_page.dart` | 582 | UI Page |
| `firestore.rules` | +9 | Sécurité |
| `functions/index.js` | +120 | Cloud Function |

---

## 🎯 Cas d'usage rapides

### Cas 1: Superadmin veut voir ses articles
```
Profil → Commerce → "Mes articles en ligne"
↓
Voir 4 articles en grille
```

### Cas 2: Modifier prix d'un article
```
Cliquer ... sur article
↓
Cliquer "Modifier"
↓
Changer prix
↓
Sauvegarder
↓
✅ Mis à jour
```

### Cas 3: Réduire stock
```
Cliquer ... sur article
↓
Cliquer "Mettre à jour le stock"
↓
Entrer nouvelle valeur
↓
✅ Stock mis à jour
```

### Cas 4: Ajouter nouvel article
```
Cliquer "Ajouter un article"
↓
Remplir: nom, catégorie, prix, stock
↓
Sauvegarder
↓
✅ Article créé
```

---

## 🔐 Permissions

| Rôle | Lire | Créer | Modifier | Supprimer |
|------|------|--------|----------|-----------|
| User | ✅ actifs | ❌ | ❌ | ❌ |
| Admin | ✅ actifs | ❌ | ❌ | ❌ |
| Superadmin | ✅ | ✅ | ✅ | ✅ |

---

## 📊 Les 4 articles

```
1. Casquette MAS'LIVE
   - Prix: 19.99€
   - Stock: 100

2. T-shirt MAS'LIVE
   - Prix: 24.99€
   - Stock: 150

3. Porte-clé MAS'LIVE
   - Prix: 9.99€
   - Stock: 200

4. Bandana MAS'LIVE
   - Prix: 14.99€
   - Stock: 120
```

---

## ⚡ API Service (Utilisation rapide)

```dart
// Instancier service
final service = SuperadminArticleService();

// Créer article
final article = await service.createArticle(
  name: 'Casquette',
  description: 'Une belle casquette',
  category: 'casquette',
  price: 19.99,
  imageUrl: 'https://...',
  stock: 100,
);

// Récupérer tous
final articles = await service.getAllArticles();

// Récupérer par catégorie
final casquettes = await service.getArticlesByCategory('casquette');

// Stream d'articles
final stream = service.streamActiveArticles();

// Modifier
await service.updateArticle(articleId, updatedArticle);

// Mettre à jour stock
await service.updateStock(articleId, 75);

// Activer/Désactiver
await service.toggleArticleStatus(articleId, true);

// Supprimer
await service.deleteArticle(articleId);

// Stats
final stats = await service.getArticleStats();
```

---

## 🎨 Accès via UI

### Via Profil superadmin
```
Menu Compte
  ↓
Mon Profil
  ↓
Section Commerce
  ↓
"Mes articles en ligne"
  ↓
SuperadminArticlesPage
```

### Via Dashboard Admin
```
Menu Compte
  ↓
Espace Admin
  ↓
Dashboard Administrateur
  ↓
Section Commerce
  ↓
"Articles Superadmin"
  ↓
SuperadminArticlesPage
```

---

## 🧪 Test rapide

```bash
# 1. Build
cd /workspaces/MASLIVE/app
flutter build web --release

# 2. Deploy
firebase deploy --only hosting

# 3. Test
# - Se connecter
# - Aller Profil → Mes articles en ligne
# - Voir 4 articles
```

---

## ❓ Problèmes courants

### Articles ne s'affichent pas
- ✓ Vérifier initialisation Cloud Function
- ✓ Vérifier Firestore collection `superadmin_articles`
- ✓ Vérifier isActive = true

### Permission denied
- ✓ Vérifier utilisateur est superadmin
- ✓ Vérifier Firestore Rules déployées
- ✓ Vérifier token Firebase valide

### Images ne s'affichent pas
- ✓ Vérifier imageUrl non vide
- ✓ Vérifier URL publique/accessible

---

## 📚 Documentation

Voir:
- `SUPERADMIN_ARTICLES_GUIDE.md` - Guide complet
- `SUPERADMIN_ARTICLES_ARCHITECTURE.md` - Architecture détaillée
- `SUPERADMIN_ARTICLES_TESTS.md` - Tests complets
- `SUPERADMIN_ARTICLES_UI.md` - Interface UI

---

## ✅ Checklist rapide

- [x] Code créé
- [x] Code modifié
- [x] Règles Firestore
- [x] Cloud Function
- [x] Documentation
- [ ] Déployer (À faire)
- [ ] Initialiser (À faire)
- [ ] Tester (À faire)

---

## 🚀 Commandes de déploiement

```bash
# 1. Commit
cd /workspaces/MASLIVE
git add . && git commit -m "feat: gestion articles superadmin" && git push

# 2. Deploy Functions + Rules
firebase deploy --only functions,firestore:rules

# 3. Build + Deploy Hosting
cd app && flutter pub get && flutter build web --release && cd ..
firebase deploy --only hosting

# 4. Initialiser articles (une seule fois)
firebase functions:shell
> initSuperadminArticles()
```

---

**Prêt à utiliser!** 🎉
