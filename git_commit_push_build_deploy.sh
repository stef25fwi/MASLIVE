#!/usr/bin/env bash

# 🚀 Commit + Push + Build + Deploy (Hosting)
# ==========================================

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

echo "╔════════════════════════════════════════════════╗"
echo "║  🚀 Commit + Push + Build + Deploy             ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Step 1: Git Add (safe)
echo "📝 Stage all changes..."

# Guard: ne jamais committer node_modules
if git ls-files -z "functions/node_modules" "functions/node_modules/**" | head -c 1 | grep -q .; then
    echo "❌ ERREUR: functions/node_modules est suivi par Git."
    echo "   Fix: git rm -r --cached functions/node_modules && git commit -m 'chore: stop tracking functions node_modules'"
    exit 1
fi

# Guard: ne jamais committer de secrets (tracked)
if git ls-files -z "serviceAccountKey.json" | head -c 1 | grep -q .; then
    echo "❌ ERREUR: serviceAccountKey.json est suivi par Git (secret)."
    echo "   Fix: git rm --cached serviceAccountKey.json && git commit -m 'chore: stop tracking service account key'"
    exit 1
fi
if git ls-files -z -- "*firebase-adminsdk*.json" | head -c 1 | grep -q .; then
    echo "❌ ERREUR: un fichier *firebase-adminsdk*.json est suivi par Git (secret)."
    echo "   Fix: git rm --cached <fichier>.json && git commit -m 'chore: stop tracking firebase admin sdk key'"
    exit 1
fi
if git ls-files -z "functions/.env" "functions/.env.*" "functions/.runtimeconfig.json" | tr '\0' '\n' | grep -v '\.env\.example' | head -c 1 | grep -q .; then
    echo "❌ ERREUR: un fichier de config secret Functions est suivi par Git (functions/.env* ou functions/.runtimeconfig.json)."
    echo "   Fix: git rm --cached functions/.env* functions/.runtimeconfig.json && git commit -m 'chore: stop tracking functions secrets'"
    exit 1
fi

git add -A

# Guard: ne jamais stager de secrets (même si présents en untracked)
if git diff --cached --name-only -- "serviceAccountKey.json" | head -n 1 | grep -q .; then
    echo "❌ ERREUR: serviceAccountKey.json est stagé (secret)."
    echo "   Fix: git reset -- serviceAccountKey.json && ajoute-le à .gitignore"
    exit 1
fi
if git diff --cached --name-only -- "*firebase-adminsdk*.json" | head -n 1 | grep -q .; then
    echo "❌ ERREUR: un fichier *firebase-adminsdk*.json est stagé (secret)."
    echo "   Fix: git reset -- <fichier>.json && ajoute-le à .gitignore"
    exit 1
fi
if git diff --cached --name-only -- "functions/.env" "functions/.env."* "functions/.runtimeconfig.json" | grep -v '\.env\.example' | head -n 1 | grep -q .; then
    echo "❌ ERREUR: un fichier secret Functions est stagé (functions/.env* ou functions/.runtimeconfig.json)."
    echo "   Fix: git reset -- functions/.env functions/.env.* functions/.runtimeconfig.json && ajoute-les à .gitignore"
    exit 1
fi

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
cd "$repo_root/app"
source "$repo_root/.env" 2>/dev/null || true
export MAPBOX_ACCESS_TOKEN="${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-}}"

if [ -n "$MAPBOX_ACCESS_TOKEN" ]; then
    flutter pub get
    flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
else
    echo "❌ ERREUR: aucun token Mapbox trouvé (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN)."
    echo "➡️  Renseigne-le dans /workspaces/MASLIVE/.env (task: 'MASLIVE: 🗺️ Set Mapbox token (.env)')"
    echo "    puis relance le build/deploy."
    exit 1
fi
echo "✅ Build completed"
echo ""

# Step 5: Deploy Hosting
echo "🌐 Deploying to Firebase Hosting..."
cd "$repo_root"

FIREBASE_CMD="firebase"
if ! command -v firebase >/dev/null 2>&1; then
    echo "ℹ️ firebase CLI non trouvé, fallback via npx firebase-tools"
    if command -v npx >/dev/null 2>&1; then
        FIREBASE_CMD="npx --yes firebase-tools"
    else
        echo "❌ ERREUR: ni firebase CLI ni npx ne sont disponibles."
        exit 127
    fi
fi

$FIREBASE_CMD deploy --only hosting
echo "✅ Deployed"
echo ""

echo "╔════════════════════════════════════════════════╗"
echo "║  ✨ Deployment successful!                     ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "🌍 Live at: https://maslive.web.app"
echo ""
