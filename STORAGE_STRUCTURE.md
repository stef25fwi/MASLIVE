# 📁 Structure de Stockage Firebase Storage

## Architecture Organisée

Toutes les photos sont stockées avec une hiérarchie cohérente et des conventions de nommage claires.

### 🗂️ Arborescence Complète

```
storage/
├── products/                      # Produits boutique
│   ├── global/                    # Produits globaux
│   │   └── {productId}/
│   │       ├── original/
│   │       │   ├── 0.jpg          # Photo principale
│   │       │   ├── 1.jpg          # Photos additionnelles
│   │       │   └── 2.jpg
│   │       └── thumbnails/
│   │           ├── 0_thumb.jpg    # Miniature 300x300
│   │           └── 0_preview.jpg  # Preview 800x800
│   └── {shopId}/                  # Produits par shop
│       └── {productId}/
│           ├── original/
│           └── thumbnails/
│
├── media/                         # Médias (photos/vidéos)
│   ├── global/                    # Médias globaux
│   │   └── {mediaId}/
│   │       ├── original/
│   │       │   └── media.jpg
│   │       └── thumbnails/
│   └── {scopeId}/                 # Médias par scope (group, shop)
│       └── {mediaId}/
│           ├── original/
│           └── thumbnails/
│
├── articles/                      # Articles/Posts
│   └── {articleId}/
│       ├── original/
│       │   ├── cover.jpg          # Image de couverture
│       │   └── content_0.jpg      # Images dans le contenu
│       └── thumbnails/
│           └── cover_thumb.jpg
│
├── groups/                        # Groupes
│   └── {groupId}/
│       ├── avatar/
│       │   ├── original.jpg
│       │   └── thumb.jpg
│       ├── banner/
│       │   └── banner.jpg
│       ├── products/              # Produits du groupe
│       │   └── {productId}/
│       │       ├── original/
│       │       │   ├── 1.jpg
│       │       │   └── 2.jpg
│       │       └── thumbnails/
│       └── media/                 # Médias du groupe
│           └── {mediaId}/
│               ├── original/
│               └── thumbnails/
│
├── commerce/                      # Soumissions commerce (legacy)
│   └── {scopeId}/
│       └── {ownerUid}/
│           └── {submissionId}/
│               ├── original/
│               └── thumbnails/
│
├── users/                         # Profils utilisateurs
│   └── {userId}/
│       ├── avatar/
│       │   ├── original.jpg
│       │   └── thumb_200.jpg
│       └── uploads/               # Autres uploads utilisateur
│
└── temp/                          # Uploads temporaires (nettoyés après 24h)
    └── {userId}/
        └── {timestamp}/
            └── temp_image.jpg
```

---

## 📐 Conventions

### Nommage des Fichiers

- **Original** : `0.jpg`, `1.jpg`, `2.jpg`, etc. (numérotés par ordre)
- **Thumbnail** : `{index}_thumb.jpg` (ex: `0_thumb.jpg`)
- **Preview** : `{index}_preview.jpg` (ex: `0_preview.jpg`)
- **Cover** : `cover.jpg` (image principale d'un article/groupe)
- **Avatar** : `original.jpg` + `thumb.jpg`

### Tailles Standards

| Type | Dimensions | Usage |
|------|-----------|--------|
| `original` | Variable (max 4096px) | Photo complète haute qualité |
| `preview` | 800x800px | Affichage détails produit |
| `thumb` | 300x300px | Grilles, listes, cartes |
| `avatar_thumb` | 200x200px | Avatars utilisateurs/groupes |

### Métadonnées

Chaque fichier uploadé inclut :
```json
{
  "contentType": "image/jpeg",
  "customMetadata": {
    "uploadedBy": "{userId}",
    "uploadedAt": "{ISO8601}",
    "originalName": "photo_maslive.jpg",
    "category": "product|media|article|avatar",
    "parentId": "{productId|mediaId|articleId}",
    "parentType": "product|media|article|group|user"
  }
}
```

---

## 🎯 Mapping par Fonctionnalité

### Produits Boutique
- **Chemin** : `products/{shopId}/{productId}/original/{index}.jpg`
- **Thumbnails** : `products/{shopId}/{productId}/thumbnails/{index}_thumb.jpg`
- **Usage** : Shop page, admin produits, créer produit

### Médias (Photos/Vidéos)
- **Chemin** : `media/{scopeId}/{mediaId}/original/media.{ext}`
- **Thumbnails** : `media/{scopeId}/{mediaId}/thumbnails/media_thumb.jpg`
- **Usage** : Galerie, Instagram feed, commerce médias

### Articles/Posts
- **Chemin** : `articles/{articleId}/original/cover.jpg`
- **Content** : `articles/{articleId}/original/content_{index}.jpg`
- **Usage** : Blog, actualités, publications

### Groupes
- **Avatar** : `groups/{groupId}/avatar/original.jpg`
- **Banner** : `groups/{groupId}/banner/banner.jpg`
- **Produits** : `groups/{groupId}/products/{productId}/original/{index}.jpg`
- **Usage** : Profils groupes, boutiques groupes

---

## 🔒 Règles de Sécurité

Les Storage Rules correspondantes sont dans `storage.rules` :

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Products: admin et groupe peuvent write
    match /products/{shopId}/{productId}/{subpath=**} {
      allow read: if true;
      allow write: if request.auth != null && (
        hasRole('superAdmin') || 
        hasRole('admin') ||
        isGroupMember(shopId)
      );
    }
    
    // Media: authenticated users
    match /media/{scopeId}/{mediaId}/{subpath=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Articles: admin only
    match /articles/{articleId}/{subpath=**} {
      allow read: if true;
      allow write: if hasRole('admin') || hasRole('superAdmin');
    }
    
    // Groups: group members
    match /groups/{groupId}/{subpath=**} {
      allow read: if true;
      allow write: if request.auth != null && isGroupMember(groupId);
    }
    
    // Users: own profile only
    match /users/{userId}/{subpath=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Temp: 24h auto-delete via Cloud Function
    match /temp/{userId}/{subpath=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## 🚀 Migration depuis Structure Legacy

### Anciennes structures à migrer :

1. **Commerce submissions** : `commerce/{scopeId}/{ownerUid}/{submissionId}/*`
   - → `products/{scopeId}/{productId}/original/*` ou `media/{scopeId}/{mediaId}/original/*`

2. **Group shops** : `group_shops/{groupId}/products/{filename}`
   - → `groups/{groupId}/products/{productId}/original/{index}.jpg`

3. **Admin products** : `products/{productId}/{timestamp}.jpg`
   - → `products/global/{productId}/original/0.jpg`

### Script de Migration

Un script `migrate_storage_structure.js` peut être créé pour :
- Scanner les anciennes structures
- Copier vers nouvelles structures avec métadonnées
- Mettre à jour les références Firestore
- Supprimer les anciens fichiers (après validation)

---

## 📊 Avantages de cette Structure

✅ **Cohérence** : Tous les uploads suivent la même logique  
✅ **Évolutivité** : Ajout facile de nouveaux types (events/, pois/, etc.)  
✅ **Performance** : Miniatures pré-générées pour chargement rapide  
✅ **Maintenance** : Dossiers par entité = suppression en cascade facile  
✅ **Sécurité** : Rules granulaires par type de contenu  
✅ **Traçabilité** : Métadonnées sur chaque fichier  
✅ **Backup** : Structure claire pour synchro/backup sélectif  

---

## 🛠️ Prochaines Étapes

1. Créer service `storage_service.dart` avec méthodes unifiées
2. Implémenter génération automatique de thumbnails (Cloud Functions)
3. Migrer anciens uploads vers nouvelle structure
4. Mettre à jour toutes les pages upload pour utiliser nouveau service
5. Déployer Storage Rules
6. Tester tous les flux d'upload
7. Cleanup anciens dossiers après migration complète
