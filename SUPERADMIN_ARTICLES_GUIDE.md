# 🎽 Système de Gestion des Articles Superadmin

## Vue d'ensemble

Le superadmin peut maintenant gérer les articles de base de MAS'LIVE :
- **Casquette** 
- **T-shirt**
- **Porte-clé**
- **Bandana**

Ces articles sont stockés dans la collection `superadmin_articles` de Firestore et accessibles depuis :
1. Le **profil superadmin** → Section Commerce → "Mes articles en ligne"
2. Le **dashboard admin** → Section Commerce → Tuile "Articles Superadmin"

---

## 🏗️ Architecture Firestore

### Collection: `superadmin_articles`

Structure d'un article:
```javascript
{
  id: "doc_id",                    // ID du document
  name: "Casquette MAS'LIVE",      // Nom de l'article
  description: "...",              // Description détaillée
  category: "casquette",           // casquette|tshirt|porteclé|bandana
  price: 19.99,                    // Prix en euros
  imageUrl: "https://...",         // URL de l'image
  stock: 100,                      // Quantité en stock
  isActive: true,                  // Article visible/caché
  sku: "CASQUETTE-001",            // Stock Keeping Unit
  tags: ["casquette", "outdoor"],  // Tags pour recherche
  metadata: {},                    // Données additionnelles (optionnel)
  createdAt: Timestamp,            // Date de création
  updatedAt: Timestamp,            // Date de dernière modification
}
```

---

## 🔐 Règles Firestore

```javascript
// Articles Superadmin (casquette, tshirt, porteclé, bandana)
match /superadmin_articles/{articleId} {
  // Tous les utilisateurs peuvent lire les articles actifs
  allow read: if isSignedIn() && resource.data.isActive == true;
  
  // Seul le superadmin peut créer, modifier, supprimer
  allow create, update, delete: if isSuperAdmin();
}
```

**Permissions:**
- ✅ Tous les utilisateurs (signés) : **Lecture** des articles actifs
- ✅ Superadmin seulement : **Créer, Modifier, Supprimer**

---

## 🚀 Mise en route

### 1️⃣ Initialisation (une seule fois)

Appeler la Cloud Function `initSuperadminArticles` depuis la console Firebase:

```bash
firebase functions:shell
> initSuperadminArticles()
```

Ou depuis l'app:
```dart
// À implémenter dans AdminMainDashboard ou SuperadminArticlesPage
final result = await FirebaseFunctions.instance
  .httpsCallable('initSuperadminArticles')
  .call();
print(result.data); // { success: true, created: 4 }
```

**Résultat:**
- 4 articles de base créés (casquette, t-shirt, porte-clé, bandana)
- Chacun avec stock initial et prix définis
- Status: `isActive: true`

### 2️⃣ Accès à la page de gestion

**Via Profil Superadmin:**
1. Aller dans **Mon Profil** (AccountUiPage)
2. Scroller vers **Section Commerce**
3. Cliquer sur **"Mes articles en ligne"** (nouvelle ligne)

**Via Dashboard Admin:**
1. Aller dans **Espace Admin** → **Dashboard Administrateur**
2. Section **Commerce**
3. Cliquer sur tuile **"Articles Superadmin"**

---

## ⚙️ Fonctionnalités

### ✅ Affichage des articles

- Grille responsive 2 colonnes
- Filtrage par catégorie (Tous / Casquette / T-shirt / Porte-clé / Bandana)
- Affichage: Image, Nom, Prix, Stock
- Indicateur de stock restant

### ✅ Ajouter un article

- Cliquer **"Ajouter un article"**
- Formulaire modal:
  - Nom (requis)
  - Catégorie (sélection)
  - Prix en € (requis)
  - Stock (requis)
  - Description (optionnel)
  - SKU (optionnel)
- Sauvegarde automatique dans Firestore

### ✅ Modifier un article

- Cliquer **"..."** sur une carte
- Sélectionner **"Modifier"**
- Éditer les champs
- Sauvegarder les changements

### ✅ Gérer le stock

- Cliquer **"..."** sur une carte
- Sélectionner **"Mettre à jour le stock"**
- Entrer la nouvelle quantité
- Stock mis à jour automatiquement

### ✅ Activer/Désactiver

- Cliquer **"..."** sur une carte
- Sélectionner **"Activer"** ou **"Désactiver"**
- Article visible/caché immédiatement

### ✅ Supprimer

- Cliquer **"..."** sur une carte
- Sélectionner **"Supprimer"**
- Confirmation requise

---

## 📱 Interface utilisateur

### Page SuperadminArticlesPage

**Widgets:**
- `RainbowHeader` : Titre "Mes articles en ligne"
- `_buildCategoryFilter()` : Filtres par catégorie
- `_buildArticleCard()` : Carte article avec image et infos
- `_ArticleEditDialog` : Dialog de création/modification

**Couleurs:**
- Tuile de la page: **Teal** (Colors.teal)
- Boutons: **Violet foncé** (Colors.deepPurple)

---

## 🔄 Service: SuperadminArticleService

### Méthodes principales

```dart
// Créer un article
Future<SuperadminArticle> createArticle({
  required String name,
  required String description,
  required String category,
  required double price,
  required String imageUrl,
  required int stock,
})

// Récupérer un article
Future<SuperadminArticle?> getArticle(String id)

// Récupérer tous les articles
Future<List<SuperadminArticle>> getAllArticles()

// Récupérer par catégorie
Future<List<SuperadminArticle>> getArticlesByCategory(String category)

// Stream d'articles actifs
Stream<List<SuperadminArticle>> streamActiveArticles({String? category})

// Mettre à jour
Future<void> updateArticle(String id, SuperadminArticle article)

// Mettre à jour le stock
Future<void> updateStock(String id, int newStock)

// Activer/Désactiver
Future<void> toggleArticleStatus(String id, bool isActive)

// Supprimer
Future<void> deleteArticle(String id)

// Statistiques
Future<Map<String, int>> getArticleStats()
```

---

## 📊 Modèle: SuperadminArticle

```dart
class SuperadminArticle {
  final String id;
  final String name;
  final String description;
  final String category; // casquette, tshirt, porteclé, bandana
  final double price;
  final String imageUrl;
  final int stock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sku;
  final List<String> tags;
  final Map<String, dynamic>? metadata;
}
```

---

## 📂 Structure des fichiers

```
app/lib/
├── models/
│   └── superadmin_article.dart           # Modèle de données
├── services/
│   └── superadmin_article_service.dart   # Service Firestore
├── pages/
│   └── superadmin_articles_page.dart     # Page principale
├── constants/
│   └── superadmin_articles_init.dart     # Données d'initialisation
└── widgets/commerce/
    └── commerce_section_card.dart         # Mise à jour: ajout bouton

functions/
└── index.js                              # Fonction cloud initSuperadminArticles

firestore.rules                            # Nouvelles règles pour collection
```

---

## 🧪 Test

### Test 1: Initialiser les articles

1. Aller dans Firebase Console
2. Appeler `initSuperadminArticles()`
3. Vérifier que 4 articles sont créés dans Firestore
4. Contrôler que les stocks et prix sont corrects

### Test 2: Afficher les articles

1. Se connecter en tant que superadmin
2. Aller dans Profil → Commerce → "Mes articles en ligne"
3. Vérifier que les 4 articles s'affichent avec images
4. Tester le filtre par catégorie

### Test 3: Ajouter/Modifier/Supprimer

1. Ajouter un nouvel article
2. Vérifier création dans Firestore
3. Modifier prix/stock/description
4. Vérifier mise à jour
5. Supprimer article test
6. Vérifier suppression

### Test 4: Contrôle d'accès

1. **Utilisateur standard**: Peut lire articles actifs, ne peut pas modifier
2. **Admin**: Peut lire articles actifs, ne peut pas modifier
3. **Superadmin**: Peut créer, modifier, supprimer (✅ testé)

---

## 🎯 Cas d'usage

### Scenario 1: Lancement initial
```
1. Superadmin se connecte
2. Va dans Dashboard Admin → Articles Superadmin
3. Voit 4 articles pré-créés
4. Ajoute images depuis Storage
5. Modifie stocks/prix si nécessaire
```

### Scenario 2: Gestion quotidienne
```
1. Superadmin reçoit commande casquette
2. Va dans Profil → Mes articles en ligne
3. Cherche "casquette" via filtres
4. Clique "..." → "Mettre à jour le stock"
5. Diminue stock de 1
```

### Scenario 3: Nouveau produit
```
1. Superadmin veut ajouter variation t-shirt
2. Clique "Ajouter un article"
3. Catégorie: t-shirt
4. Remplit formulaire
5. Article visible immédiatement après sauvegarde
```

---

## 🔗 Intégrations futures

Possibilités d'extension:

- ✨ **Upload d'images**: Intégrer image picker + Firebase Storage
- ✨ **Variations**: Tailles, couleurs (métadata)
- ✨ **Promotions**: Réductions, codes promo
- ✨ **Analytics**: Ventes par article, tendances
- ✨ **Notifications**: Alertes stock faible
- ✨ **Commandes**: Lier à commandes utilisateurs

---

## ❓ FAQ

**Q: Qui peut modifier les articles?**
A: Seul le superadmin peut créer/modifier/supprimer. Les autres utilisateurs peuvent seulement lire les articles actifs.

**Q: Les articles sont-ils visibles aux utilisateurs?**
A: Les articles actifs (`isActive: true`) sont lisibles par tous les utilisateurs signés. Ils peuvent être affichés dans la boutique ou un catalogue.

**Q: Peux-je uploader des images?**
A: Actuellement, vous devez fournir une URL. Une intégration image picker + Firebase Storage peut être ajoutée.

**Q: Comment ajouter une nouvelle catégorie?**
A: Modifier `SuperadminArticleService.validCategories` et les règles Firestore si nécessaire.

---

## 📞 Support

Pour tout problème:
1. Vérifier les logs Firebase Cloud Functions
2. Contrôler les permissions Firestore Rules
3. Vérifier la connexion internet (iOS/Android/Web)
4. Redéployer les fonctions et règles
