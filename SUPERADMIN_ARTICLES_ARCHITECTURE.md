# 🗺️ Architecture - Gestion des Articles Superadmin

## 📊 Vue d'ensemble du système

```
┌─────────────────────────────────────────────────────────────────┐
│                     SUPERADMIN ARTICLES                          │
│                   (casquette, tshirt, porteclé, bandana)        │
└─────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
          ┌──────────────┐  ┌────────────┐  ┌─────────────┐
          │  UI/Frontend │  │  Services  │  │   Data      │
          │   (Pages)    │  │ (Business) │  │ (Firestore) │
          └──────────────┘  └────────────┘  └─────────────┘
```

---

## 🏗️ Couches d'architecture

### 1️⃣ Couche Présentation (UI)

```dart
app/lib/
├── pages/
│   └── superadmin_articles_page.dart [582 lignes] ⭐
│       ├── SuperadminArticlesPage (Widget)
│       ├── _buildCategoryFilter() (FilterChip x5)
│       ├── _buildArticleCard() (Grille 2 colonnes)
│       ├── _showAddArticleDialog()
│       ├── _showEditArticleDialog()
│       ├── _showUpdateStockDialog()
│       └── _ArticleEditDialog (Dialog)
│
└── widgets/commerce/
    └── commerce_section_card.dart [Modifié]
        ├── CommerceSectionCard
        └── [NEW] Bouton "Mes articles en ligne"

├── admin/
└── admin_main_dashboard.dart [Modifié]
    └── [NEW] Tuile "Articles Superadmin" (Commerce section)
```

**Widgets UI:**
- `RainbowHeader` - Titre "Mes articles en ligne"
- `FilterChip` x5 - Filtres catégories
- `GridView` - Grille d'articles
- `Card` - Cartes article
- `AlertDialog` - Dialogues édition
- `SnackBar` - Messages

---

### 2️⃣ Couche Métier (Services)

```dart
app/lib/services/
└── superadmin_article_service.dart [185 lignes] ⭐
    ├── SuperadminArticleService (Singleton)
    │
    ├── CRUD:
    │   ├── createArticle()
    │   ├── getArticle(id)
    │   ├── getAllArticles()
    │   ├── getArticlesByCategory(category)
    │   ├── updateArticle(id, article)
    │   ├── updateStock(id, newStock)
    │   ├── toggleArticleStatus(id, isActive)
    │   └── deleteArticle(id)
    │
    ├── Streams:
    │   └── streamActiveArticles({category})
    │
    └── Utilitaires:
        ├── validCategories (liste des 4 catégories)
        └── getArticleStats()
```

**Pattern:** Singleton + Stream-based (Réactif)

---

### 3️⃣ Couche Modèle (Data)

```dart
app/lib/models/
└── superadmin_article.dart [130 lignes] ⭐
    └── SuperadminArticle
        ├── id: String
        ├── name: String
        ├── description: String
        ├── category: String (enum-like)
        ├── price: double
        ├── imageUrl: String
        ├── stock: int
        ├── isActive: bool
        ├── createdAt: DateTime
        ├── updatedAt: DateTime
        ├── sku: String?
        ├── tags: List<String>
        ├── metadata: Map<String, dynamic>?
        │
        ├── Methods:
        │   ├── fromMap(data, docId)
        │   ├── toMap()
        │   ├── toJson()
        │   ├── fromJson(json)
        │   └── copyWith(...)
        │
        └── Constants:
            └── validCategories = ['casquette', 'tshirt', 'porteclé', 'bandana']
```

**Immutabilité:** copyWith() pour modifications

---

### 4️⃣ Couche Données (Firestore)

```
Firestore Database
│
└── superadmin_articles/ [Collection]
    │
    ├── {docId1}
    │   ├── name: "Casquette MAS'LIVE"
    │   ├── category: "casquette"
    │   ├── price: 19.99
    │   ├── stock: 100
    │   ├── isActive: true
    │   └── ...
    │
    ├── {docId2}
    │   ├── name: "T-shirt MAS'LIVE"
    │   ├── category: "tshirt"
    │   ├── price: 24.99
    │   ├── stock: 150
    │   ├── isActive: true
    │   └── ...
    │
    ├── {docId3}
    │   ├── name: "Porte-clé MAS'LIVE"
    │   ├── category: "porteclé"
    │   ├── price: 9.99
    │   ├── stock: 200
    │   ├── isActive: true
    │   └── ...
    │
    └── {docId4}
        ├── name: "Bandana MAS'LIVE"
        ├── category: "bandana"
        ├── price: 14.99
        ├── stock: 120
        ├── isActive: true
        └── ...
```

---

### 5️⃣ Couche Sécurité (Firestore Rules)

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Articles Superadmin
    match /superadmin_articles/{articleId} {
      
      // Lecture: Tous les users signés (articles actifs)
      allow read: if isSignedIn() && resource.data.isActive == true;
      
      // Écriture: Superadmin seulement
      allow create, update, delete: if isSuperAdmin();
    }
  }
}
```

**Règles:**
- 📖 READ: Public signés (articles actifs)
- ✏️ WRITE: Superadmin seulement

---

### 6️⃣ Couche Cloud Functions

```javascript
functions/index.js
│
└── initSuperadminArticles() [Cloud Function] ⭐
    │
    ├── Authentification:
    │   ├── Vérifier user signée
    │   ├── Vérifier rôle superAdmin
    │   └── Rejeter si non autorisé
    │
    ├── Initialisation:
    │   ├── Récupérer articles existants
    │   ├── Skip si déjà initialisé
    │   ├── Créer 4 articles de base
    │   ├── Set timestamps serveur
    │   └── Batch commit
    │
    └── Réponse:
        ├── { success: true, created: 4 }
        ├── { success: true, created: 0 } (si déjà init)
        └── { error } (si erreur)
```

**Exécution:** Une seule fois après déploiement

---

## 🔄 Flux de données

### Création d'article

```
UI Dialog
  ↓
FormData (name, category, price, stock)
  ↓
SuperadminArticleService.createArticle()
  ↓
  ├─→ Validation (catégorie, prix, etc.)
  ├─→ SuperadminArticle(...)
  ├─→ toMap()
  └─→ Firestore.add()
       ↓
       Collection: superadmin_articles
       ├─→ createdAt: FieldValue.serverTimestamp()
       ├─→ updatedAt: FieldValue.serverTimestamp()
       └─→ {docId} créé
  ↓
Réponse article créé
  ↓
SnackBar "✅ Article créé avec succès"
  ↓
StreamBuilder refresh automatique (UI update)
```

### Lecture d'articles

```
UI Page Mounted
  ↓
streamActiveArticles({category})
  ↓
Query: superadmin_articles
  ├─→ where('isActive', ==, true)
  ├─→ where('category', ==, category) [si spécifié]
  ├─→ orderBy('updatedAt', descending)
  └─→ snapshots() [Stream]
  ↓
SuperadminArticle.fromMap() x N
  ↓
StreamBuilder<List<SuperadminArticle>>
  ├─→ ConnectionState.waiting → CircularProgressIndicator
  ├─→ Data: GridView avec articles
  └─→ Empty: Texte "Aucun article trouvé"
```

### Modification d'article

```
UI Dialog + Formulaire
  ↓
Récupérer article existant
  ↓
Éditer champs
  ↓
Article.copyWith(...)
  ↓
SuperadminArticleService.updateArticle(id, article)
  ↓
Firestore.doc(id).update({...})
  ├─→ updatedAt: FieldValue.serverTimestamp()
  └─→ Tous les champs updatés
  ↓
Stream recalcule → UI refresh
  ↓
SnackBar "✅ Article mis à jour"
```

---

## 📱 Navigation UI

### Menu Profil Superadmin

```
AccountUiPage (Mon Profil)
│
├─ RainbowHeader
├─ _AvatarBlock
├─ [IF _canSubmitCommerce]
│  │
│  └─ CommerceSectionCard
│     ├─ "Ajouter un article" → CreateProductPage
│     ├─ "Ajouter un média" → CreateMediaPage
│     ├─ "Mes contenus" → MySubmissionsPage
│     └─ "Mes articles en ligne" [NEW] → SuperadminArticlesPage ⭐
│
└─ Navigation Tiles
```

### Dashboard Admin

```
AdminMainDashboard
│
├─ Carte & Navigation
├─ Tracking & Groupes
├─ Commerce
│  ├─ Produits
│  ├─ Commandes
│  ├─ Aperçu boutique
│  ├─ Articles à valider
│  ├─ Stock
│  ├─ Modération Commerce
│  ├─ Analytics Commerce
│  └─ "Articles Superadmin" [NEW] ⭐
│     └─→ SuperadminArticlesPage
├─ Utilisateurs
├─ Comptes Professionnels
└─ Analytics & Système
```

---

## 🔗 Dépendances et imports

### Dépendances packages utilisées

```yaml
flutter:
  - material.dart
  - cloud_firestore: ^4.x
  - firebase_auth: ^4.x
  
Custom:
  - models/superadmin_article.dart
  - services/superadmin_article_service.dart
  - widgets/rainbow_header.dart
  - ui/widgets/honeycomb_background.dart
```

### Imports interdépendances

```
superadmin_articles_page.dart
├─→ imports superadmin_article.dart
├─→ imports superadmin_article_service.dart
├─→ imports rainbow_header.dart
└─→ imports honeycomb_background.dart

commerce_section_card.dart
├─→ imports superadmin_articles_page.dart

admin_main_dashboard.dart
└─→ imports superadmin_articles_page.dart
```

---

## 🔐 Matrice de permissions

| Action | User Standard | Admin | SuperAdmin |
|--------|---------------|-------|-----------|
| Lire articles actifs | ✅ | ✅ | ✅ |
| Créer article | ❌ | ❌ | ✅ |
| Modifier article | ❌ | ❌ | ✅ |
| Supprimer article | ❌ | ❌ | ✅ |
| Accéder à la page | ❌ | ❌ | ✅ |

---

## 🎯 Points d'extension

### Futures améliorations

1. **Upload d'images**
   - ImagePicker + Firebase Storage
   - Compression automatique
   - Multiple images par article

2. **Variations d'articles**
   - Tailles (S, M, L, XL)
   - Couleurs
   - Stockage par variante

3. **Analytics**
   - Ventes par article
   - Tendances
   - Revenus

4. **Intégrations**
   - Notifications stock faible
   - Export CSV/PDF
   - Synchronisation avec système externe

5. **Admin avancé**
   - Recherche/filtrage avancé
   - Bulk operations
   - Historique modifications
   - Audit trail

---

## 📊 Diagramme des états

```
Article Lifecycle

┌─────────────────┐
│   Créé (NEW)    │
│  isActive=true  │
└────────┬────────┘
         │
         ├──→ Modifier → [Édité]
         │
         ├──→ Désactiver → [Caché]
         │                (isActive=false)
         │
         └──→ Supprimer → [Supprimé]
                         (Effacé de Firestore)

Rétention: Caché → Réactiver
```

---

## 🧮 Statistiques de code

| Fichier | Lignes | Type |
|---------|--------|------|
| superadmin_article.dart | 130 | Modèle |
| superadmin_article_service.dart | 185 | Service |
| superadmin_articles_page.dart | 582 | UI Page |
| commerce_section_card.dart (delta) | +20 | Modification |
| admin_main_dashboard.dart (delta) | +40 | Modification |
| firestore.rules (delta) | +9 | Règles |
| functions/index.js (delta) | +120 | Cloud Function |
| Documentation | +800 | Guides |
| **TOTAL** | **~1500** | |

---

## ✅ Checklist architecture

- [x] Couche présentation (UI) ✨
- [x] Couche métier (Services) ✨
- [x] Couche modèle (Data) ✨
- [x] Couche données (Firestore) ✨
- [x] Couche sécurité (Rules) ✨
- [x] Couche serverless (Functions) ✨
- [x] Navigation intégrée ✨
- [x] Documentation architecture ✨

**Architecture complète et modulaire!** 🎉
