#!/usr/bin/env bash
# =============================================================================
# Déploiement des règles Firebase Storage UNIQUEMENT (storage.rules).
#
# Pourquoi un script dédié ?
#   `build_and_deploy.sh` déploie par défaut `--only hosting`: les règles
#   Storage ne partent donc PAS avec un déploiement normal. Or l'upload de
#   photos POI écrit sous `places/**`, chemin protégé par ces règles. Si les
#   règles live ne sont pas à jour, l'upload échoue en « Permission denied ».
#
# Ce script ne rebuild rien (les règles sont indépendantes du build web) et
# pousse `storage.rules` en quelques secondes.
#
# Usage:
#   ./deploy_storage_rules.sh
# =============================================================================
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v firebase >/dev/null 2>&1; then
  echo "❌ firebase CLI introuvable (npm i -g firebase-tools)." >&2
  exit 127
fi

if [[ ! -f "$repo_root/storage.rules" ]]; then
  echo "❌ storage.rules introuvable à la racine du repo." >&2
  exit 1
fi

cd "$repo_root"
echo "🔒 Déploiement des règles Storage (storage.rules)…"
firebase deploy --only storage
echo "✅ Règles Storage déployées."
