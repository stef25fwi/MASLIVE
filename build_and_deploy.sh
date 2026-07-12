#!/usr/bin/env bash
# =============================================================================
# Build web (release) PUIS déploiement Firebase Hosting — atomique et sûr.
#
# GARANTIE: on ne déploie JAMAIS si le build a échoué.
#   - `set -e`  => la moindre commande en échec stoppe le script.
#   - vérif explicite que `app/build/web/main.dart.js` a bien été (re)généré
#     par CE build avant d'appeler `firebase deploy`.
# Rappel du piège évité: `firebase deploy` publie ce qu'il y a dans build/web,
# même si le build a échoué => sinon on redéploie un ancien build périmé.
#
# Usage:
#   ./build_and_deploy.sh
#   ./build_and_deploy.sh --only hosting,functions   # cible de déploiement custom
#
# Token Mapbox: variable MAPBOX_ACCESS_TOKEN exportée, sinon lu depuis .env
# (clé MAPBOX_ACCESS_TOKEN=... ou MAPBOX_PUBLIC_TOKEN=...). Jamais committé.
# =============================================================================
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Par défaut on déploie le hosting ET les règles Storage: l'upload de photos
# POI écrit sous `places/**`, protégé par storage.rules. Les garder synchro à
# chaque déploiement évite un « Permission denied » dû à des règles live
# périmées. Override possible: `./build_and_deploy.sh --only hosting`.
deploy_target="${*:---only hosting,storage}"

# --- Flutter sur le PATH -----------------------------------------------------
# shellcheck disable=SC1091
source "$repo_root/flutter_env.sh" 2>/dev/null || true
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ flutter introuvable sur le PATH." >&2
  exit 127
fi
if ! command -v firebase >/dev/null 2>&1; then
  echo "❌ firebase CLI introuvable (npm i -g firebase-tools)." >&2
  exit 127
fi

# --- Token Mapbox ------------------------------------------------------------
if [[ -z "${MAPBOX_ACCESS_TOKEN:-}" && -f "$repo_root/.env" ]]; then
  MAPBOX_ACCESS_TOKEN="$(grep -E '^(MAPBOX_ACCESS_TOKEN|MAPBOX_PUBLIC_TOKEN)=' "$repo_root/.env" \
    | tail -n1 | cut -d= -f2- | tr -d '"'"'"' \r')"
fi
if [[ -z "${MAPBOX_ACCESS_TOKEN:-}" || "${MAPBOX_ACCESS_TOKEN}" == pk...* ]]; then
  echo "❌ MAPBOX_ACCESS_TOKEN manquant ou placeholder." >&2
  echo "   → export MAPBOX_ACCESS_TOKEN=\"pk.xxxx\"   (ou renseigne .env)" >&2
  exit 1
fi

marker="$repo_root/app/build/web/main.dart.js"

echo "🏗️  Étape 1/2 — flutter build web --release"
echo "──────────────────────────────────────────"
# On supprime l'ancien artefact: si le build échoue, il n'existera pas
# => la vérification ci-dessous bloquera le déploiement d'un build périmé.
rm -f "$marker"

cd "$repo_root/app"
# set -e stoppe ici si le build renvoie un code != 0.
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"

if [[ ! -f "$marker" ]]; then
  echo "❌ Build KO: $marker introuvable — déploiement ANNULÉ." >&2
  exit 1
fi
echo "✅ Build OK: $marker généré."

echo ""
echo "🚀 Étape 2/2 — firebase deploy $deploy_target"
echo "──────────────────────────────────────────"
cd "$repo_root"
# shellcheck disable=SC2086
firebase deploy $deploy_target

echo ""
echo "🎉 Terminé — https://maslive.web.app"
