#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."/app

echo "== Flutter web setup =="

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ flutter introuvable dans PATH" >&2
  exit 1
fi

echo "1) Activer le support web (si nécessaire)"
flutter config --enable-web || true

echo "2) Vérifier un exécutable Chrome/Chromium"
if [ -z "${CHROME_EXECUTABLE:-}" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    export CHROME_EXECUTABLE="$(command -v google-chrome)"
  elif command -v chromium >/dev/null 2>&1; then
    export CHROME_EXECUTABLE="$(command -v chromium)"
  elif command -v chromium-browser >/dev/null 2>&1; then
    export CHROME_EXECUTABLE="$(command -v chromium-browser)"
  fi
fi

if [ -n "${CHROME_EXECUTABLE:-}" ]; then
  echo "✅ CHROME_EXECUTABLE=${CHROME_EXECUTABLE}"
else
  cat <<'EOF'
⚠️  Chrome/Chromium introuvable.

Pour obtenir les devices web (Chrome + web-server) :
- Debian/Ubuntu (souvent en container) :
    sudo apt-get update
    sudo apt-get install -y chromium || sudo apt-get install -y chromium-browser

Puis relance ce script (ou exporte CHROME_EXECUTABLE vers le binaire).
EOF
fi

echo
echo "3) flutter doctor (web)"
flutter doctor -v || true

echo
echo "4) flutter devices"
flutter devices || true

echo
echo "Ensuite, tu peux lancer: flutter run -d web-server"
