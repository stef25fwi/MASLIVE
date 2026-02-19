# MASLIVE
MAS’LIVE app geolocalisation live tracking shop.

## Commandes “à cliquer” (VS Code)

Des tâches VS Code sont disponibles dans [.vscode/tasks.json](.vscode/tasks.json):

- `MASLIVE: Setup and deploy`
- `MASLIVE: Flutter pub get`
- `MASLIVE: Firebase deploy`

Pour les lancer: `Terminal` → `Run Task...` puis choisir la tâche.

## Commande terminal (copier-coller)

- Tout-en-un: `bash /workspaces/MASLIVE/scripts/setup_deploy.sh`
- Ou en une ligne: `cd /workspaces/MASLIVE/app && flutter pub get && cd /workspaces/MASLIVE && firebase deploy --only firestore:rules,functions`

## Migration Firebase Functions → Node.js 22

La configuration du projet est préparée pour Node.js 22:

- `functions/package.json` → `"engines": { "node": "22" }`
- `firebase.json` → `"runtime": "nodejs22"`

Déploiement recommandé:

- `cd /workspaces/MASLIVE/functions && npm ci`
- `cd /workspaces/MASLIVE && firebase deploy --only functions --project maslive`
