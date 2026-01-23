# 📊 Comparaison: Ancienne vs Nouvelle Structure Média

## Structure de l'ancienne page

### `media_galleries_page.dart` (AVANT)

```
┌─────────────────────────────────┐
│  RainbowHeader: "Médias"        │
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │ Filtres (statiques)       │  │
│  │ - Pays ▼                  │  │
│  │ - Date ▼                  │  │
│  │ - Événement ▼             │  │
│  │ - Groupe ▼                │  │
│  │ - Photographe ▼           │  │
│  │ [Réinitialiser]           │  │
│  └───────────────────────────┘  │
├─────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐       │
│  │ Galerie │ │ Galerie │       │
│  │  Card   │ │  Card   │       │
│  │         │ │         │       │
│  │ 45 📷   │ │ 32 📷   │       │
│  └─────────┘ └─────────┘       │
│  ┌─────────┐ ┌─────────┐       │
│  │ Galerie │ │ Galerie │       │
│  │  Card   │ │  Card   │       │
│  └─────────┘ └─────────┘       │
└─────────────────────────────────┘
```

**Limitations:**
- ❌ Pas de sélection multiple
- ❌ Pas de panier
- ❌ Filtres pas en cascade
- ❌ Pas de tri
- ❌ Clic → navigation vers détail (pas de preview)

---

## Structure de la nouvelle page

### `media_galleries_page_v2.dart` (APRÈS)

```
┌─────────────────────────────────┐
│  RainbowHeader: "Médias"  🛒[3] │ ← Badge panier
├─────────────────────────────────┤
│  ┌ FILTRES (STICKY) ──────────┐ │ ← Reste visible au scroll
│  │ Pays ▼  |  Date 📅         │ │
│  │ Événement ▼  |  Groupe ▼   │ │
│  │ Photographe ▼  |  Trier ▼  │ │
│  │           [Réinitialiser]   │ │
│  └────────────────────────────┘ │
├─────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐       │
│  │    ☑    │ │    ○    │       │ ← Checkmarks sélection
│  │ Galerie │ │ Galerie │       │
│  │  Card   │ │  Card   │       │
│  │         │ │         │       │
│  │ 45 📷   │ │ 32 📷   │       │
│  │ 8.99€ 🛒│ │ 6.50€ 🛒│       │ ← Prix + bouton panier
│  └─────────┘ └─────────┘       │
│  ┌─────────┐ ┌─────────┐       │
│  │ Au      │ │    ○    │       │
│  │ panier  │ │ Galerie │       │ ← Badge "Au panier"
│  │         │ │  Card   │       │
│  └─────────┘ └─────────┘       │
├─────────────────────────────────┤
│  2 sélectionnées • 15.49€      │ ← Barre de sélection
│  [Décocher] [Ajouter au panier]│   (apparaît si sélection > 0)
└─────────────────────────────────┘
```

**Nouveautés:**
- ✅ Checkmarks pour sélection multiple
- ✅ Badge panier dans header
- ✅ Filtres sticky (restent visibles au scroll)
- ✅ Filtres en cascade (pays → date → événement → groupe → photographe)
- ✅ Tri (récent, nb photos, prix)
- ✅ Barre de sélection en bas
- ✅ Preview modale au clic
- ✅ Panier modal avec checkout
- ✅ Prix calculé automatiquement (nb photos × prix unitaire)

---

## Flux utilisateur

### Ancienne version

```
Clic sur galerie
    ↓
Navigation vers GalleryDetailPage
    ↓
Voir les photos
```

### Nouvelle version

```
Voir galeries
    ↓
┌─ Clic checkmark → Sélectionner
│       ↓
│   Barre sélection apparaît
│       ↓
│   [Ajouter au panier]
│       ↓
│   Badge panier s'incrémente
│
├─ Clic card → Preview modale
│       ↓
│   Voir détails + checkmark + panier
│
└─ Clic 🛒 badge → Panier modal
        ↓
    Voir panier complet
        ↓
    [Payer] → Checkout Stripe
```

---

## Filtres: Comparaison

### Ancienne version
```dart
// Filtres indépendants (pas de logique de cascade)
_selectedPays = 'Guadeloupe';
_selectedEvent = 'Carnaval'; // ❌ Peut ne pas exister en Guadeloupe
```

### Nouvelle version
```dart
// Filtres cascadés (logique intelligente)
_filters = FilterState(country: 'Guadeloupe');
// → Les options événements ne montrent QUE les événements 
//   qui existent en Guadeloupe

_filters = _filters.copyWith(eventName: 'Carnaval');
// → Les options groupes ne montrent QUE les groupes 
//   qui ont participé au Carnaval en Guadeloupe
```

---

## Avantages techniques

| Fonctionnalité | Ancienne | Nouvelle |
|----------------|----------|----------|
| **State Management** | setState | Provider (InheritedNotifier) |
| **Filtres** | Statiques | Cascadés dynamiques |
| **Performance** | StreamBuilder | Future + setState |
| **UX Sélection** | ❌ | ✅ Checkmarks + barre |
| **Panier** | ❌ | ✅ Provider partagé |
| **Sticky Header** | ❌ | ✅ SliverPersistentHeader |
| **Tri** | Firestore | Client-side (flexible) |
| **Preview** | Navigation | Modale (meilleur UX) |
| **Prix** | ❌ | ✅ Calculé auto |

---

## Migration

### Étape 1: Mise à jour Firestore

```bash
# Ajouter les nouveaux champs aux documents existants
node scripts/migrate_media_galleries.js

# Ou créer une galerie de test
node scripts/migrate_media_galleries.js --test
```

### Étape 2: Remplacer l'import

```dart
// AVANT
import 'pages/media_galleries_page.dart';

// APRÈS
import 'pages/media_shop_wrapper.dart';
```

### Étape 3: Remplacer l'usage

```dart
// AVANT
MediaGalleriesPage(groupId: 'all')

// APRÈS
MediaShopWrapper(groupId: 'all')
```

### Étape 4: Tester

- ✅ Filtres fonctionnent
- ✅ Sélection multiple fonctionne
- ✅ Panier fonctionne
- ✅ Badge panier s'incrémente
- ✅ Preview modale s'ouvre
- ✅ Tri fonctionne

---

## Prochaines améliorations

1. **Persistance panier** - Sauvegarder dans SharedPreferences
2. **Checkout Stripe** - Implémenter le vrai paiement
3. **Favoris** - Système de favoris pour galeries
4. **Partage** - Partager une galerie
5. **Téléchargement** - Après achat, télécharger les photos
6. **Watermark** - Preview avec watermark avant achat
7. **Recherche** - Barre de recherche textuelle
8. **Notifications** - Alertes nouvelles galeries

---

## Support

Pour toute question, voir:
- [MEDIA_SHOP_STRUCTURE.md](MEDIA_SHOP_STRUCTURE.md) - Documentation complète
- [INTEGRATION_EXAMPLES.dart](INTEGRATION_EXAMPLES.dart) - Exemples d'intégration
