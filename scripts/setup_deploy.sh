#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/MASLIVE/app
flutter pub get

cd /workspaces/MASLIVE
firebase deploy --only firestore:rules,functions

echo "OK: pub get + deploy terminés"
