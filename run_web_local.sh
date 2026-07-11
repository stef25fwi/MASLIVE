#!/usr/bin/env bash
# =============================================================================
# Lancement web "connu bon" — carte Mapbox + POIs qui s'affichent.
#
# Objectif: reproduire À L'IDENTIQUE la configuration validée le 2026-07-11
# (analyze propre, carte OK, POIs visibles) sans avoir à se rappeler du port,
# du token ni des flags --dart-define.
#
# Usage:
#   ./run_web_local.sh                 # port auto (8080, sinon 8090, 8100...)
#   ./run_web_local.sh 8095            # port imposé
#
# Token Mapbox (dans l'ordre de priorité):
#   1) variable d'env MAPBOX_ACCESS_TOKEN déjà exportée
#   2) fichier .env  (clé MAPBOX_ACCESS_TOKEN=... ou MAPBOX_PUBLIC_TOKEN=...)
# Le token n'est JAMAIS committé (.env est gitignoré).
# =============================================================================
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_root/app"

# --- Flutter sur le PATH -----------------------------------------------------
# shellcheck disable=SC1091
source "$repo_root/flutter_env.sh" 2>/dev/null || true
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ flutter introuvable sur le PATH." >&2
  exit 127
fi

# --- Résolution du token Mapbox ---------------------------------------------
if [[ -z "${MAPBOX_ACCESS_TOKEN:-}" && -f "$repo_root/.env" ]]; then
  # Lit .env sans l'exécuter (évite l'injection). Accepte les 2 noms de clé.
  MAPBOX_ACCESS_TOKEN="$(grep -E '^(MAPBOX_ACCESS_TOKEN|MAPBOX_PUBLIC_TOKEN)=' "$repo_root/.env" \
    | tail -n1 | cut -d= -f2- | tr -d '"'"'"' \r')"
fi

if [[ -z "${MAPBOX_ACCESS_TOKEN:-}" || "${MAPBOX_ACCESS_TOKEN}" == pk...* ]]; then
  echo "❌ MAPBOX_ACCESS_TOKEN manquant ou placeholder." >&2
  echo "   → export MAPBOX_ACCESS_TOKEN=\"pk.xxxx\"   (ou renseigne .env)" >&2
  exit 1
fi

# --- Choix du port (repli automatique si occupé) -----------------------------
pick_free_port() {
  local wanted="${1:-8080}"
  for p in "$wanted" 8090 8100 8110 8120; do
    if ! { exec 3<>"/dev/tcp/127.0.0.1/$p"; } 2>/dev/null; then
      echo "$p"; return 0
    fi
    exec 3>&- 2>/dev/null || true
  done
  echo "$wanted"
}
PORT="$(pick_free_port "${1:-8080}")"

echo "🚀 flutter run -d web-server  (port $PORT)"
echo "   → ouvre l'onglet PORTS de Codespaces puis 'Open in Browser'"
echo ""

exec flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port "$PORT" \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
