# MASLIVE
MAS’LIVE  app geolocalitsation live tracking shop 

## Commandes “à cliquer” (VS Code)

Des tâches VS Code sont disponibles dans [.vscode/tasks.json](.vscode/tasks.json):

- `MASLIVE: Setup and deploy`
- `MASLIVE: Flutter pub get`
- `MASLIVE: Firebase deploy`

Pour les lancer: `Terminal` → `Run Task...` puis choisir la tâche.

## Commande terminal (copier-coller)

- Tout-en-un: `bash /workspaces/MASLIVE/scripts/setup_deploy.sh`
- Ou en une ligne: `cd /workspaces/MASLIVE/app && flutter pub get && cd /workspaces/MASLIVE && firebase deploy --only firestore:rules,functions`
