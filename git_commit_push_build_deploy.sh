#!/bin/bash

# 🚀 Commit + Push + Build + Deploy Script
# =========================================

set -e

PROJECT_ROOT="/workspaces/MASLIVE"
cd "$PROJECT_ROOT"

echo "╔════════════════════════════════════════════════╗"
echo "║  🚀 Commit + Push + Build + Deploy             ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Step 1: Git Add
echo "📝 Stage all changes..."
git add .
echo "✅ Done"
echo ""

# Step 2: Git Commit
COMMIT_MSG="${1:-}"

if [[ -z "$COMMIT_MSG" ]]; then
    read -r -p "Message de commit: " COMMIT_MSG
fi

if [[ -z "$COMMIT_MSG" ]]; then
    COMMIT_MSG="chore: maintenance"
fi

echo "💾 Committing: $COMMIT_MSG"
git commit -m "$COMMIT_MSG" || echo "⚠️  Nothing to commit (working tree clean)"
echo ""

# Step 3: Git Push
echo "📤 Pushing to main..."
git push origin main
echo "✅ Pushed"
echo ""

# Step 4: Build Web with Mapbox Token
echo "🔨 Building web with Mapbox token..."
cd "$PROJECT_ROOT/app"
source "$PROJECT_ROOT/.env" 2>/dev/null || true
export MAPBOX_ACCESS_TOKEN="${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-}}"

if [ -n "$MAPBOX_ACCESS_TOKEN" ]; then
    echo "🗺️  Token detected: ${MAPBOX_ACCESS_TOKEN:0:15}..."
    flutter pub get
    flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
else
    echo "⚠️  No Mapbox token found, building without it"
    flutter pub get
    flutter build web --release
fi
echo "✅ Build completed"
echo ""

# Step 5: Deploy Hosting
echo "🌐 Deploying to Firebase Hosting..."
cd "$PROJECT_ROOT"
firebase deploy --only hosting
echo "✅ Deployed"
echo ""

echo "╔════════════════════════════════════════════════╗"
echo "║  ✨ Deployment successful!                     ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "🌍 Live at: https://maslive.web.app"
echo ""
