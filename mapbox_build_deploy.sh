#!/bin/bash

# 🗺️ Mapbox Wizard Build & Deploy Script
# Usage: ./mapbox_build_deploy.sh [token]
# Example: ./mapbox_build_deploy.sh pk_YOUR_TOKEN

set -e

echo "🗺️  Mapbox Circuit Wizard - Build & Deploy"
echo "═════════════════════════════════════════════════════════════"

# Check token provided
if [ -z "$1" ]; then
    echo "⚠️  No Mapbox token provided - using fallback mode"
    MAPBOX_TOKEN=""
else
    echo "✅ Using Mapbox token: ${1:0:10}..."
    MAPBOX_TOKEN="$1"
fi

# Get to repo root
cd "$(dirname "$0")"
echo "📁 Working directory: $(pwd)"

# 1. Clean previous builds
echo ""
echo "🧹 Cleaning previous builds..."
cd app
if [ -d "build" ]; then
    rm -rf build
    echo "   ✅ Cleaned app/build/"
fi

# 2. Get dependencies
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get 2>&1 | tail -5
echo "   ✅ Dependencies ready"

# 3. Analyze code
echo ""
echo "🔍 Analyzing code for issues..."
if flutter analyze --no-fatal-infos 2>&1 | grep -q "0 issues"; then
    echo "   ✅ No issues found"
else
    echo "   ⚠️  Some issues found (non-fatal)"
fi

# 4. Build web
echo ""
echo "🏗️  Building Flutter Web..."
if [ -n "$MAPBOX_TOKEN" ]; then
    echo "   With Mapbox token..."
    flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN" 2>&1 | tail -10
else
    echo "   Without Mapbox token (fallback mode)..."
    flutter build web --release 2>&1 | tail -10
fi
echo "   ✅ Build complete"

# 5. Check build size
echo ""
echo "📊 Build size:"
du -sh build/web/ | awk '{print "   " $1}'

# 6. Return to root
cd ..

# 7. Deploy
echo ""
echo "🚀 Deploying to Firebase Hosting..."
read -p "   Continue with deployment? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    firebase deploy --only hosting 2>&1 | tail -10
    echo "   ✅ Deployment complete"
    echo ""
    echo "🎉 All done! Check your deployment at:"
    echo "   https://maslive.web.app"
else
    echo "   ❌ Deployment cancelled"
    echo "   To deploy later, run: firebase deploy --only hosting"
fi

echo ""
echo "═════════════════════════════════════════════════════════════"
echo "✨ Mapbox wizard integration active"
if [ -n "$MAPBOX_TOKEN" ]; then
    echo "   Mode: Full Mapbox GL JS"
else
    echo "   Mode: Grid Fallback (no token)"
fi
echo "═════════════════════════════════════════════════════════════"
