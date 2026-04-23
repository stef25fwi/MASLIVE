#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

commit_message="${1:-Fix home map startup style pipeline}"
push_after="${2:-}"

if ! git diff --cached --quiet; then
  echo "Refus: l'index contient deja des changements stages."
  echo "Vide ou commit d'abord l'index courant, puis relance ce script."
  exit 1
fi

echo "Stage des fichiers dedies au correctif..."
git add app/lib/models/market_poi.dart app/lib/ui/map/maslive_map_web.dart app/test/market_poi_test.dart app/lib/pages/default_map_page.dart

echo "Resume des changements stages :"
git diff --cached --stat

echo "Creation du commit..."
git commit -m "$commit_message"

if [ "$push_after" = "push" ]; then
  echo "Push vers origine..."
  git push
fi

echo "✅ Correctif commité ! (Utiliser le script de deploy ensuite si besoin)"
