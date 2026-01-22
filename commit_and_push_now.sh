#!/bin/bash
# Commit et push les modifications actuelles

set -e

echo "📤 COMMIT & PUSH"
echo "================"
echo ""

# Stage
echo "📝 Stage des fichiers..."
git add -A
echo "✅ Stagés"
echo ""

# Commit
echo "📦 Commit..."
git commit -m "fix: remove maslivepink.png from splash gallery"
echo "✅ Committés"
echo ""

# Push
echo "🔄 Push vers origin main..."
git push origin main
echo "✅ Main pushée"
echo ""

echo "✅ TERMINÉ!"
