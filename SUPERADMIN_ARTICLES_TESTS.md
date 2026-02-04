# 🧪 Guide de test - Gestion des Articles Superadmin

## 📋 Tests avant déploiement

### Test 1: Compilation Flutter ✅

```bash
cd /workspaces/MASLIVE/app

# 1. Récupérer les dépendances
flutter pub get
# ✅ Résultat attendu: "Got dependencies!"

# 2. Analyser le code
flutter analyze --no-fatal-warnings
# ✅ Résultat attendu: "No issues found!" ou "X warnings"

# 3. Générer le build web
flutter build web --release
# ✅ Résultat attendu: Build réussi (Exit code: 0)
```

**Acceptation:** Aucune erreur de compilation

---

### Test 2: Vérification des fichiers créés ✅

```bash
cd /workspaces/MASLIVE

# Vérifier existence des fichiers
ls -la app/lib/models/superadmin_article.dart
ls -la app/lib/services/superadmin_article_service.dart
ls -la app/lib/pages/superadmin_articles_page.dart
ls -la app/lib/constants/superadmin_articles_init.dart

# ✅ Résultat attendu: 4 fichiers existants
```

---

### Test 3: Vérification des modifications ✅

```bash
cd /workspaces/MASLIVE

# 1. CommerceSectionCard
grep -n "Mes articles en ligne" app/lib/widgets/commerce/commerce_section_card.dart
# ✅ Résultat attendu: Ligne trouvée

# 2. AdminMainDashboard  
grep -n "Articles Superadmin" app/lib/admin/admin_main_dashboard.dart
# ✅ Résultat attendu: Ligne trouvée

# 3. Firestore Rules
grep -n "superadmin_articles" firestore.rules
# ✅ Résultat attendu: 3 matches

# 4. Cloud Functions
grep -n "initSuperadminArticles" functions/index.js
# ✅ Résultat attendu: 2 matches (fonction + exports)
```

---

### Test 4: Intégrité des imports 📦

```dart
// superadmin_articles_page.dart
✅ import 'package:flutter/material.dart';
✅ import 'package:image_picker/image_picker.dart';
✅ import '../models/superadmin_article.dart';
✅ import '../services/superadmin_article_service.dart';
✅ import '../widgets/rainbow_header.dart';
✅ import '../ui/widgets/honeycomb_background.dart';

// commerce_section_card.dart
✅ import '../pages/superadmin_articles_page.dart';

// admin_main_dashboard.dart
✅ import '../pages/superadmin_articles_page.dart';
```

**Procédure:** Vérifier dans les fichiers source
**Acceptation:** Tous les imports résolus

---

## 🚀 Tests de déploiement

### Pré-déploiement

```bash
# 1. Vérifier que on est sur main
git branch | grep "*"
# ✅ Résultat attendu: "* main"

# 2. Vérifier que la branche est propre
git status
# ✅ Résultat attendu: "On branch main, nothing to commit"
```

### Déploiement étape 1: Commit

```bash
cd /workspaces/MASLIVE

git add .
git commit -m "feat: gestion articles superadmin (casquette, tshirt, porteclé, bandana)"
git push origin main

# ✅ Résultat attendu:
#    - Commit créé
#    - Push réussi
#    - GitHub montre nouveau commit
```

### Déploiement étape 2: Functions + Rules

```bash
cd /workspaces/MASLIVE

firebase deploy --only functions,firestore:rules

# ✅ Résultat attendu:
#    - ✔ functions: Deployment complete
#    - ✔ firestore: Deploy complete
#    - Exit code: 0
```

### Déploiement étape 3: Hosting

```bash
cd /workspaces/MASLIVE/app

flutter pub get
flutter build web --release

cd /workspaces/MASLIVE

firebase deploy --only hosting

# ✅ Résultat attendu:
#    - ✔ hosting: Deployed successfully
#    - Exit code: 0
```

---

## ✅ Tests fonctionnels post-déploiement

### Test 1: Initialisation des articles (UNE SEULE FOIS)

**Préalable:** Être connecté en tant que superadmin

**Procédure:**
```bash
firebase functions:shell
> initSuperadminArticles()
```

**Résultat attendu:**
```json
{
  "success": true,
  "created": 4,
  "message": "4 articles superadmin créés avec succès"
}
```

**Vérification Firestore:**
1. Firebase Console → Firestore
2. Collection: `superadmin_articles`
3. 4 documents:
   - Casquette (price: 19.99, stock: 100)
   - T-shirt (price: 24.99, stock: 150)
   - Porte-clé (price: 9.99, stock: 200)
   - Bandana (price: 14.99, stock: 120)

---

### Test 2: Accès page "Mes articles en ligne"

**Préalable:**
- Être connecté en tant que superadmin
- Articles initialisés dans Firestore

**Procédure:**
1. Aller dans "Mon Profil"
2. Scroller vers "Section Commerce"
3. Cliquer sur "Mes articles en ligne"

**Résultat attendu:**
- ✅ Page se charge
- ✅ Header "Mes articles en ligne" visible
- ✅ Filtres catégories affichés (Tous, Casquette, T-shirt, Porte-clé, Bandana)
- ✅ Grille 2 colonnes avec les 4 articles
- ✅ Chaque carte montre: Image, Nom, Prix, Stock

---

### Test 3: Accès page depuis Dashboard Admin

**Procédure:**
1. Aller dans "Espace Admin"
2. Cliquer sur "Dashboard Administrateur"
3. Section "Commerce"
4. Cliquer sur tuile "Articles Superadmin"

**Résultat attendu:**
- ✅ Même page que "Mes articles en ligne"
- ✅ Tous les articles affichés
- ✅ Tuile disparaît si pas superadmin (✅ à vérifier après)

---

### Test 4: Filtrer par catégorie

**Procédure:**
1. Depuis page articles
2. Cliquer sur "Casquette"
3. Vérifier que seule la casquette s'affiche

**Résultat attendu (pour chaque catégorie):**
- [ ] Filtrer "Tous" → 4 articles
- [ ] Filtrer "Casquette" → 1 article (Casquette MAS'LIVE)
- [ ] Filtrer "T-shirt" → 1 article (T-shirt MAS'LIVE)
- [ ] Filtrer "Porte-clé" → 1 article (Porte-clé MAS'LIVE)
- [ ] Filtrer "Bandana" → 1 article (Bandana MAS'LIVE)

---

### Test 5: Ajouter un nouvel article

**Procédure:**
1. Cliquer "Ajouter un article"
2. Remplir formulaire:
   - Nom: "Test Article"
   - Catégorie: "casquette"
   - Prix: "29.99"
   - Stock: "50"
   - Description: "Test description"
3. Cliquer "Sauvegarder"

**Résultat attendu:**
- ✅ SnackBar "✅ Article créé avec succès"
- ✅ Nouvel article apparaît en grille
- ✅ Vérification Firestore: Document créé
- ✅ Timestamps correctes (createdAt, updatedAt)

---

### Test 6: Modifier un article

**Procédure:**
1. Cliquer "..." sur un article
2. Sélectionner "Modifier"
3. Changer le prix (ex: 29.99 → 39.99)
4. Cliquer "Sauvegarder"

**Résultat attendu:**
- ✅ SnackBar "✅ Article mis à jour"
- ✅ Article en grille affiche nouveau prix (39.99)
- ✅ Firestore: price = 39.99, updatedAt = maintenant

---

### Test 7: Mettre à jour le stock

**Procédure:**
1. Cliquer "..." sur un article
2. Sélectionner "Mettre à jour le stock"
3. Entrer nouvelle valeur: "75"
4. Cliquer "Mettre à jour"

**Résultat attendu:**
- ✅ SnackBar "✅ Stock mis à jour"
- ✅ Carte article: Stock: 75
- ✅ Firestore: stock = 75, updatedAt = maintenant

---

### Test 8: Désactiver un article

**Procédure:**
1. Cliquer "..." sur un article
2. Sélectionner "Désactiver"

**Résultat attendu:**
- ✅ Article disparaît de la grille
- ✅ Firestore: isActive = false
- ✅ Filtres: Article n'apparaît plus

**Procédure inverse (Réactiver):**
1. Cliquer "..." sur l'article caché (via recherche directe)
2. Sélectionner "Activer"

**Résultat attendu:**
- ✅ Article réapparaît
- ✅ Firestore: isActive = true

---

### Test 9: Supprimer un article

**Procédure:**
1. Cliquer "..." sur un article
2. Sélectionner "Supprimer"
3. Confirmer suppression

**Résultat attendu:**
- ✅ SnackBar "✅ Article supprimé"
- ✅ Article disparaît de la grille
- ✅ Firestore: Document supprimé

---

### Test 10: Gestion des erreurs

**Test 10a: Soumission vide**
- [ ] Cliquer "Ajouter un article"
- [ ] Laisser "Nom" vide
- [ ] Cliquer "Sauvegarder"
- ✅ SnackBar d'erreur: "Le nom est requis"

**Test 10b: Valeurs invalides**
- [ ] Remplir Prix: "abc" (non numérique)
- [ ] Remplir Stock: "-5" (négatif)
- ✅ Les valeurs sont converties (0 ou parsées correctement)

**Test 10c: Connexion Internet perdue**
- [ ] Simuler connexion perdue pendant modification
- ✅ Erreur Firebase capturée et affichée

---

## 🔐 Tests de sécurité

### Test 1: Lecture articles par utilisateur standard

**Procédure:**
1. Se connecter en tant qu'utilisateur standard
2. Essayer d'accéder à `superadmin_articles` (direct Firestore)

**Résultat attendu:**
- ✅ Articles actifs lisibles (isActive=true)
- ✅ Champs article visibles

---

### Test 2: Modification par utilisateur standard

**Procédure:**
1. Se connecter en tant qu'utilisateur standard
2. Essayer de modifier document `superadmin_articles`

**Résultat attendu:**
- ❌ Permission denied (Firestore Rules bloque)

---

### Test 3: Modification par admin (non-superadmin)

**Procédure:**
1. Se connecter en tant qu'admin regular
2. Essayer de modifier document `superadmin_articles`

**Résultat attendu:**
- ❌ Permission denied (Firestore Rules bloque)

---

### Test 4: Modification par superadmin

**Procédure:**
1. Se connecter en tant que superadmin
2. Modifier document `superadmin_articles`

**Résultat attendu:**
- ✅ Permission granted
- ✅ Modification réussie

---

## 📊 Checklist de test complète

### Pré-déploiement
- [ ] Compilation Flutter OK
- [ ] Pas d'erreurs d'import
- [ ] Fichiers créés
- [ ] Modifications vérifiées
- [ ] Règles Firestore correctes
- [ ] Cloud Functions valides

### Post-déploiement
- [ ] Initialisation des articles (4)
- [ ] Accès page "Mes articles en ligne"
- [ ] Accès page depuis Dashboard Admin
- [ ] Filtrage par catégorie (5 options)
- [ ] Créer nouvel article
- [ ] Modifier article existant
- [ ] Mettre à jour stock
- [ ] Activer/Désactiver article
- [ ] Supprimer article
- [ ] Gestion erreurs

### Sécurité
- [ ] User standard: Lire articles actifs
- [ ] User standard: Bloqué modifier
- [ ] Admin: Bloqué modifier
- [ ] Superadmin: Peut tout faire

### UI/UX
- [ ] Pages se chargent rapidement
- [ ] Images s'affichent correctement
- [ ] Dialogues réactifs
- [ ] Messages d'erreur clairs
- [ ] Navigation fluide

---

## 🎯 Critères d'acceptation

### Pour aller en production:
✅ Tous les tests pré-déploiement réussis
✅ Tous les tests post-déploiement réussis
✅ Tous les tests de sécurité réussis
✅ UI/UX validation complète
✅ Aucune erreur dans les logs Firebase
✅ Performance acceptable (< 2s load)

### KPIs:
- ✅ Articles créés en < 1 seconde
- ✅ Page charge en < 2 secondes
- ✅ Filtres réactifs (< 500ms)
- ✅ Zéro permission denied errors (légitimes)

---

## 📞 Troubleshooting

### "Articles ne s'affichent pas"
1. Vérifier initialisation Cloud Function
2. Vérifier Firestore collection existe
3. Vérifier isActive = true

### "Permission denied"
1. Vérifier utilisateur est superadmin
2. Vérifier token Firebase valide
3. Vérifier Firestore Rules déployées

### "Images ne s'affichent pas"
1. Vérifier imageUrl n'est pas vide
2. Vérifier URL accessible (publique)
3. Vérifier CORS Firebase Storage (si applicable)

---

**Tests: PRÊT POUR VALIDATION** ✨
