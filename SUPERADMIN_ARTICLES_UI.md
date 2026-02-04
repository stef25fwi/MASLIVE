# 📲 Interface Utilisateur - Superadmin Articles

## 🎨 Page SuperadminArticlesPage

```
┌──────────────────────────────────────────────────────┐
│  ← Mes articles en ligne              ⋮             │
├──────────────────────────────────────────────────────┤
│                                                      │
│  [Tous] [Casquette] [T-shirt] [Porte-clé] [Bandana]│
│   ✓      selected/highlighted                      │
│                                                      │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌─ [+ Ajouter un article] ─────────────────────┐   │
│  └────────────────────────────────────────────┘   │
│                                                      │
├──────────────────────────────────────────────────────┤
│  Grille 2 colonnes:                                 │
│                                                      │
│  ┌────────────────┐  ┌────────────────┐            │
│  │     [IMG]      │  │     [IMG]      │            │
│  │                │  │                │            │
│  │ Casquette...   │  │ T-shirt...     │            │
│  │ 19.99€         │  │ 24.99€         │            │
│  │ Stock: 100 ⋮   │  │ Stock: 150 ⋮   │            │
│  └────────────────┘  └────────────────┘            │
│                                                      │
│  ┌────────────────┐  ┌────────────────┐            │
│  │     [IMG]      │  │     [IMG]      │            │
│  │                │  │                │            │
│  │ Porte-clé...   │  │ Bandana...     │            │
│  │ 9.99€          │  │ 14.99€         │            │
│  │ Stock: 200 ⋮   │  │ Stock: 120 ⋮   │            │
│  └────────────────┘  └────────────────┘            │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 🗂️ Menu contextuel (⋮ sur carte)

```
┌─────────────────────────────────┐
│  ✏️ Modifier                     │
├─────────────────────────────────┤
│  📦 Mettre à jour le stock      │
├─────────────────────────────────┤
│  👁️ Désactiver                  │  [ou Activer si déjà désactivé]
├─────────────────────────────────┤
│  🗑️ Supprimer                   │  [Texte rouge]
└─────────────────────────────────┘
```

---

## 📝 Dialog "Ajouter un article"

```
┌────────────────────────────────────────────┐
│ Ajouter un article                   [✕]  │
├────────────────────────────────────────────┤
│                                            │
│  Nom*                                      │
│  [_________________________________]      │
│                                            │
│  Catégorie*                                │
│  [▼ casquette ▼]                          │
│     ├─ casquette                          │
│     ├─ tshirt                             │
│     ├─ porteclé                           │
│     └─ bandana                            │
│                                            │
│  Prix (€)*                                 │
│  [_________________________________]      │
│                                            │
│  Stock*                                    │
│  [_________________________________]      │
│                                            │
│  Description                               │
│  [_________________________________]      │
│  [_________________________________]      │
│  [_________________________________]      │
│                                            │
│  SKU                                       │
│  [_________________________________]      │
│                                            │
├────────────────────────────────────────────┤
│  [Annuler]              [Sauvegarder]     │
└────────────────────────────────────────────┘
```

---

## 📊 Dialog "Mettre à jour le stock"

```
┌────────────────────────────────────────────┐
│ Mettre à jour le stock               [✕]  │
├────────────────────────────────────────────┤
│                                            │
│  Nouveau stock                             │
│  [_________________________________]      │
│                                            │
├────────────────────────────────────────────┤
│  [Annuler]      [Mettre à jour]           │
└────────────────────────────────────────────┘
```

---

## 🎛️ Changement de catégorie

**AVANT (Tous sélectionné):**
```
Grille:
- Casquette (100)
- T-shirt (150)
- Porte-clé (200)
- Bandana (120)
Total: 4 articles
```

**APRÈS (Casquette sélectionné):**
```
Grille:
- Casquette (100)
Total: 1 article
```

---

## ✅ Messages de succès (SnackBar)

```
┌────────────────────────────────────────────┐
│ ✅ Article créé avec succès               │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ ✅ Article mis à jour                      │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ ✅ Stock mis à jour                        │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ ✅ Article supprimé                        │
└────────────────────────────────────────────┘
```

---

## ❌ Messages d'erreur (SnackBar)

```
┌────────────────────────────────────────────┐
│ ❌ Erreur: [Détail erreur Firebase]       │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ ❌ Le nom est requis                       │
└────────────────────────────────────────────┘
```

---

## 🔄 États de chargement

**Lors du chargement initial:**
```
┌──────────────────────────────────────────────────────┐
│                                                      │
│                  ⏳ Chargement...                    │
│                   [CircularProgressIndicator]       │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Aucun article trouvé:**
```
┌──────────────────────────────────────────────────────┐
│                                                      │
│              Aucun article trouvé                   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 📱 Responsive Design

### Desktop (> 600px)
```
┌──────────────────────────────────────────────┐
│  Article 1              Article 2             │
├──────────────────────────────────────────────┤
│  Article 3              Article 4             │
└──────────────────────────────────────────────┘
Grille: 2 colonnes
```

### Mobile (< 600px)
```
┌────────────────────┐
│     Article 1      │
├────────────────────┤
│     Article 2      │
├────────────────────┤
│     Article 3      │
├────────────────────┤
│     Article 4      │
└────────────────────┘
Grille: 1 colonne [à adapter selon écran]
```

---

## 🎨 Palette de couleurs

| Élément | Couleur | Code |
|---------|---------|------|
| Header | Rainbow gradient | Thème |
| Filtres actifs | Violet foncé | `Colors.deepPurple.shade50` |
| Bouton ajouter | Violet foncé | `Colors.deepPurple` |
| Tuile prix | Violet foncé | `Colors.deepPurple` |
| Background | Blanc | `Colors.white` |
| Text | Noir | `Colors.black` |
| Sous-texte | Gris | `Colors.grey.shade600` |

---

## 🏗️ Intégration dans les pages existantes

### 1. Profil superadmin (AccountUiPage)

```
Mon Profil
├─ Avatar & Info
├─ Section Commerce ✨ [NEW]
│  ├─ [Ajouter un article]
│  ├─ [Ajouter un média]
│  ├─ [Mes contenus]
│  └─ [Mes articles en ligne] ← SuperadminArticlesPage
├─ Compte professionnel
├─ Aide & Support
└─ À propos
```

### 2. Dashboard Admin (AdminMainDashboard)

```
Dashboard Admin
├─ Carte & Navigation
├─ Tracking & Groupes
├─ Commerce
│  ├─ [Produits]
│  ├─ [Commandes]
│  ├─ [Aperçu boutique]
│  ├─ [Articles à valider]
│  ├─ [Stock]
│  ├─ [Modération Commerce]
│  ├─ [Analytics Commerce]
│  └─ [Articles Superadmin] ← SuperadminArticlesPage ✨ [NEW]
├─ Utilisateurs
├─ Comptes Professionnels
└─ Analytics & Système
```

---

## 🔄 Flux de navigation

### Accès 1: Via Profil

```
Account Page
    ↓
[Mon Profil]
    ↓
Commerce Section
    ↓
[Mes articles en ligne]
    ↓
SuperadminArticlesPage
```

### Accès 2: Via Dashboard Admin

```
AccountAdminPage
    ↓
[Dashboard Administrateur]
    ↓
AdminMainDashboard
    ↓
Section Commerce
    ↓
Tuile [Articles Superadmin]
    ↓
SuperadminArticlesPage
```

---

## 🎯 Interactions utilisateur

### Cas 1: Créer article
```
1. Cliquer [+ Ajouter un article]
2. Remplir formulaire
3. Cliquer [Sauvegarder]
4. ✅ SnackBar succès
5. Nouvelle carte apparaît
```

### Cas 2: Modifier prix
```
1. Cliquer ... sur article
2. Sélectionner [Modifier]
3. Changer prix
4. Cliquer [Sauvegarder]
5. ✅ SnackBar "mis à jour"
6. Carte met à jour prix
```

### Cas 3: Réduire stock
```
1. Cliquer ... sur article
2. Sélectionner [Mettre à jour le stock]
3. Entrer nouvelle valeur
4. Cliquer [Mettre à jour]
5. ✅ SnackBar succès
6. Carte met à jour stock
```

### Cas 4: Supprimer article
```
1. Cliquer ... sur article
2. Sélectionner [Supprimer]
3. Confirmer suppression
4. ✅ SnackBar succès
5. Article disparaît
```

---

## 📊 Données affichées par carte

```
┌────────────────────┐
│ ┌──────────────┐  │
│ │   IMAGE      │  │
│ │  (120x120)   │  │
│ └──────────────┘  │
│                   │
│ Casquette...      │
│ 19.99€            │
│ Stock: 100 ⋮      │
│                   │
└────────────────────┘

Données affichées:
- Image (network)
- Nom (texte)
- Prix (formaté €)
- Stock (nombre)
- Menu (3-dots)
```

---

## ⏱️ Temps de réponse attendus

| Action | Temps attendu | Note |
|--------|---------------|------|
| Charger page | < 2s | Stream initiale |
| Filtrer catégorie | < 500ms | Réactif |
| Créer article | < 1s | Firestore write |
| Modifier article | < 1s | Firestore update |
| Supprimer article | < 1s | Firestore delete |
| Mettre à jour stock | < 1s | Firestore update |

---

## ✨ États visuels

### État normal (Article lisible)
```
┌─────────────────────┐
│ [IMAGE]             │
│                     │
│ Casquette           │
│ 19.99€              │
│ Stock: 100 ⋮        │
└─────────────────────┘
```

### État chargement (Récupération images)
```
┌─────────────────────┐
│ [LOADING...]        │
│                     │
│ Casquette           │
│ 19.99€              │
│ Stock: 100 ⋮        │
└─────────────────────┘
```

### État erreur (Image non trouvée)
```
┌─────────────────────┐
│ [ERROR ICON]        │
│                     │
│ Casquette           │
│ 19.99€              │
│ Stock: 100 ⋮        │
└─────────────────────┘
```

---

**UI: PRÊTE POUR UTILISATION** ✨
