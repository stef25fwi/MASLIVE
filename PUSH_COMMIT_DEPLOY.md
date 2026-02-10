# 🚀 Push Commit Deploy

## Quick Deployment Script

Script rapide pour push, commit et deploy vers Firebase **sans rebuild** de l'application Flutter.

### Usage

```bash
# Avec message de commit
./push_commit_deploy.sh "fix: update firebase rules"

# Mode interactif (demande le message)
./push_commit_deploy.sh
```

## Quand Utiliser Ce Script

✅ **Utiliser `push_commit_deploy.sh` pour:**
- Changements de configuration Firebase
- Mises à jour des Functions
- Modifications des règles Firestore
- Mises à jour des indexes Firestore
- Changements de documentation
- Corrections rapides sans rebuild

❌ **Utiliser `push_commit_build_deploy.sh` pour:**
- Changements de code Flutter
- Nouvelles fonctionnalités UI
- Mises à jour de l'application web
- Changements nécessitant un rebuild complet

## Workflow du Script

### Étapes Automatiques

1. **🔒 Security Check** - Vérifie qu'aucun secret n'est committé
2. **🧹 Clean** - Nettoie les fichiers temporaires
3. **📝 Stage** - Stage tous les changements (`git add -A`)
4. **💾 Commit** - Commit avec votre message
5. **📤 Push** - Push vers la branche courante
6. **🚀 Deploy** - Déploiement Firebase avec choix de cible

### Options de Déploiement

Lors de l'exécution, vous pouvez choisir:

1. **Full deployment** - hosting + functions + rules (complet)
2. **Hosting only** - Juste l'hébergement web
3. **Functions only** - Juste les Cloud Functions
4. **Firestore rules only** - Juste les règles et indexes
5. **Skip deployment** - Push seulement, pas de deploy

## Sécurité

Le script vérifie et bloque le commit de:
- `functions/node_modules/`
- `serviceAccountKey.json`
- `*firebase-adminsdk*.json`
- `functions/.env*`
- `functions/.runtimeconfig.json`

## Comparaison des Scripts

| Script | Build Flutter | Deploy Firebase | Durée | Usage |
|--------|---------------|-----------------|-------|-------|
| `push_commit_deploy.sh` | ❌ Non | ✅ Oui | ~2-5 min | Rapide |
| `push_commit_build_deploy.sh` | ✅ Oui | ✅ Oui | ~10-15 min | Complet |
| `quick_deploy.sh` | ❌ Non | ✅ Oui | ~1-2 min | Deploy seul |

## Exemples

### Mise à jour des règles Firestore
```bash
./push_commit_deploy.sh "fix: update firestore security rules"
# Choisir option 4: Firestore rules only
```

### Déploiement Functions
```bash
./push_commit_deploy.sh "feat: add new cloud function"
# Choisir option 3: Functions only
```

### Déploiement complet rapide
```bash
./push_commit_deploy.sh "chore: update configuration"
# Choisir option 1: Full deployment
```

### Push sans deploy
```bash
./push_commit_deploy.sh "docs: update README"
# Choisir option 5: Skip deployment
```

## Sortie du Script

Le script fournit:
- ✅ Confirmations visuelles colorées
- 📊 Résumé des actions effectuées
- 💡 Tips et recommendations
- ⚠️ Avertissements en cas de problème

## Dépendances

- Git
- Firebase CLI (`firebase`)
- Bash

## Notes

- Le script s'exécute en "strict mode" (`set -euo pipefail`)
- Arrêt immédiat si une commande échoue
- Vérifie la branche courante avant push
- Permet de skip le deploy si rien à committer

## Voir Aussi

- `push_commit_build_deploy.sh` - Version complète avec build
- `PUSH_COMMIT_BUILD_DEPLOY.md` - Documentation détaillée
- `quick_deploy.sh` - Deploy seulement (pas de git)
- `GUIDE_DEPLOIEMENT.md` - Guide général de déploiement
