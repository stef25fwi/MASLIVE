# AUDIT — Wizard Circuit (10/10) — 2026-03-06

## Portée
Audit fonctionnel + technique du flux **Wizard Circuit** (entrée + wizard pro), avec focus :
- Navigation entre étapes (Suivant/Précédent/Back système + tap stepper)
- Persistance Firestore (`map_projects.current` + sous-collections `layers/pois`)
- Risques de perte/suppression de données (pagination POIs)
- Performance perçue (snap route, writes Firestore, chargements)
- Cohérence UX (design system Glass/Tokens, stepper/header)

Fichiers principaux :
- [app/lib/admin/circuit_wizard_entry_page.dart](app/lib/admin/circuit_wizard_entry_page.dart)
- [app/lib/admin/circuit_wizard_pro_page.dart](app/lib/admin/circuit_wizard_pro_page.dart)
- [app/lib/services/circuit_repository.dart](app/lib/services/circuit_repository.dart)
- [app/lib/ui_kit/wizard/wizard_bottom_bar.dart](app/lib/ui_kit/wizard/wizard_bottom_bar.dart)
- [app/lib/ui_kit/wizard/wizard_stepper_dots_arrows.dart](app/lib/ui_kit/wizard/wizard_stepper_dots_arrows.dart)
- [app/lib/admin/circuit_map_editor.dart](app/lib/admin/circuit_map_editor.dart)

## État actuel (constats rapides)
### Points forts
- Stepper header homogène dans le wizard pro, avec ronds numérotés + flèches.
- Navigation arrière robuste : `PopScope` mappe le “back système” vers l’étape précédente au lieu de quitter.
- Réduction du risque majeur “suppression POIs” : transitions d’étapes utilisent maintenant un mode **non-destructif** (upsert sans delete).
- Le modèle `current` dans `map_projects` est la source canon + compat legacy est maintenue.

### Points à risques / dettes (priorité haute)
1) **Coûts/Perf Firestore (writes)**
   - L’upsert safe (`_upsertPoisBatch`) écrit **tous les POIs** à chaque sauvegarde safe, même si rien n’a changé.
   - Sur un projet avec 500–2000 POIs, chaque transition d’étape peut produire beaucoup d’écritures (lent + coûteux + risque de quotas).

2) **Duplication de logique de persistance**
   - `CircuitWizardProPage` a maintenant 2 voies : `_saveDraft(...)` (repo) et `_saveDraftLight()` (update direct).
   - Risque de divergence (champs oubliés, createdBy/version/status incohérents, etc.).

3) **Validation incomplète des étapes**
   - Validation explicite uniquement sur l’étape Infos (nom requis).
   - Périmètre/Tracé/Pré-pub pourraient nécessiter des garde-fous UX (min points, polygon fermé, etc.) pour éviter d’arriver plus loin avec état invalide.

4) **Cohérence UX Entry vs Pro**
   - `CircuitWizardEntryPage` est encore en style Material “standard” (AppBar/Colors/typographie), alors que le wizard pro suit le design Glass/Tokens.

5) **Blocages perçus sur snap route**
   - Lors d’un passage hors étape Tracé, un snap peut être déclenché (selon flags). Sans indicateur d’activité, l’utilisateur peut percevoir un bouton “Suivant” figé.

## Analyse détaillée

### A) Navigation (UX)
- Mécanismes :
  - `PageView` non scrollable + `_continueToStep(step)` pilote le changement.
  - Boutons bas : [app/lib/ui_kit/wizard/wizard_bottom_bar.dart](app/lib/ui_kit/wizard/wizard_bottom_bar.dart)
  - Back système : `PopScope` (dans `CircuitWizardProPage`).

- Points OK :
  - Back système recule d’une étape.
  - Bouton Précédent recule d’une étape.

- Améliorations recommandées :
  1. **Désactiver temporairement la navigation** (Suivant/tap stepper) pendant `snap`/save si l’on garde des opérations bloquantes.
  2. **Rendre explicite l’état** : mini loader sur le bouton Suivant quand un snap est en cours.

### B) Persistance Firestore & sécurité données
- Problème historique : `saveDraft` synchronisait `pois` par différence et supprimait les docs absents → dangereux avec pagination.
- État actuel : `saveDraft` accepte `deleteMissingLayers/deleteMissingPois`. En mode safe, le repo fait un upsert.

- Risques restants :
  - Upsert écrit tout, même inchangé.
  - `_saveDraftLight()` fait une update partielle directe (bien pour back), mais ajoute une seconde “source de vérité” de persistance.

- Recommandations (priorité haute) :
  1. **Ne pas synchroniser les sous-collections sur transitions d’étapes**.
     - Sur step change, écrire uniquement `map_projects.current`.
     - Ne synchroniser `layers/pois` que :
       - Quand on est sur l’étape POI (ou quand l’utilisateur clique “Sauvegarder tout”), ou
       - Avant Publication.
  2. **Suivi “dirty” local** (optionnel) : n’écrire que ce qui change.

### C) Stepper / Header
- Stepper actuel : [app/lib/ui_kit/wizard/wizard_stepper_dots_arrows.dart](app/lib/ui_kit/wizard/wizard_stepper_dots_arrows.dart)
  - Pro : compact, lisible, compatible mobile (scroll horizontal).
  - Con : les labels sont dans `Tooltip` (peu visible sur mobile), mais un label d’étape active est affiché sous le stepper.

- Recommandations :
  - Conserver tel quel. Si besoin, ajouter un compteur `Étape X/Y` sous le label (optionnel).

### D) Entry page (liste brouillons)
- `CircuitWizardEntryPage` utilise des requêtes : `map_projects.where('uid' == currentUser).orderBy(updatedAt)`.
- Risques :
  - Incohérence access control (un admin master peut vouloir voir plus que ses drafts).
  - UX visuelle différente du wizard pro.

- Recommandations :
  - Aligner UI sur Glass/Tokens (même app bar, panels, typographies).

### E) Maintenabilité
- `CircuitWizardProPage` est une page très large, multi-responsabilité :
  - UI étapes
  - logique map editor
  - persistance
  - import
  - publish + quality checks

- Recommandations :
  - À court terme : isoler la persistance step-change dans 1 méthode unique.
  - À moyen terme : extraire chaque step en widget dédié + extraire un contrôleur/service de wizard.

## Plan d’amélioration (priorisé)
### P0 — “10/10 production”
1. Transitions d’étapes : écrire **uniquement** `map_projects.current` (pas de sync `layers/pois`).
2. Publication : avant publier, forcer un sync complet + garde-fou pagination.
3. Indicateur d’activité sur snap route + disable navigation pendant snap.

### P1 — UX & cohérence
4. Re-skin `CircuitWizardEntryPage` avec Glass/Tokens + mêmes patterns.

### P2 — Performance / coûts
5. Dirty tracking POIs/layers ou sync sur demande (uniquement quand nécessaire).

## Tests recommandés (minimum)
- Test manuel :
  - Aller/retour Infos ↔ Périmètre ↔ Tracé : rien ne se reset.
  - Wizard avec 500+ POIs : navigation steps reste fluide.
  - Publication avec pagination incomplète : wizard bloque et propose “Charger tout”.

---
Fin de l’audit.
