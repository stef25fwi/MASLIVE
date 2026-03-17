#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/MASLIVE

echo "🚀 DEPLOY: Complete (web build + hosting + functions + rules + indexes)"
echo "====================================================================="

# Check if there are any changes to commit
echo "[1/3] Checking for changes..."
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "   Found changes, staging and committing..."
  git add -A
  git commit -m "chore: pre-deploy cleanup and verification" || echo "   (no new changes to commit)"
  git push origin main || echo "   (push may be no-op)"
else
  echo "   No changes to commit, skipping..."
fi

# Build Flutter web
echo ""
echo "[2/3] 🔨 Building Flutter web (release)..."
if ! command -v flutter >/dev/null 2>&1; then
  export PATH="/workspaces/MASLIVE/.flutter_sdk/bin:$PATH"
fi
{ [ -f /workspaces/MASLIVE/.env ] && source /workspaces/MASLIVE/.env; } 2>/dev/null || true
TOKEN=${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}
if [ -z "$TOKEN" ]; then
  echo "❌ ERROR: Mapbox token missing"
  exit 1
fi
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN"
cd /workspaces/MASLIVE

# Deploy (complete)
echo ""
echo "[3/3] 🚀 Deploying (hosting + functions + firestore:rules + firestore:indexes)..."
if command -v firebase >/dev/null 2>&1; then
  firebase deploy --only hosting,functions,firestore:rules,firestore:indexes
elif command -v npx >/dev/null 2>&1; then
  npx --yes firebase-tools deploy --only hosting,functions,firestore:rules,firestore:indexes
else
  echo "❌ firebase or npx not found"
  exit 127
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ DEPLOYMENT COMPLETE"
echo "════════════════════════════════════════════════════════════"
echo "   ✓ Web hosting deployed"
echo "   ✓ Cloud Functions deployed (mixed-cart callable)"
echo "   ✓ Firestore rules deployed"
echo "   ✓ Firestore indexes deployed"
echo ""
echo "📍 Live: https://maslive.web.app"
echo "📍 Console: https://console.firebase.google.com/project/maslive"
