#!/bin/bash

echo "╔════════════════════════════════════════════════╗"
echo "║  🔄 Updating V3 branch from main               ║"
echo "╚════════════════════════════════════════════════╝"

cd /workspaces/MASLIVE

echo "📥 Fetching from origin..."
git fetch origin

echo "🔀 Checking out or creating V3 branch..."
if git rev-parse --verify V3 >/dev/null 2>&1; then
    echo "✅ V3 branch exists, checking out..."
    git checkout V3
else
    echo "✨ Creating new V3 branch from origin/main..."
    git checkout -b V3 origin/main
fi

echo "🔗 Merging main into V3..."
git merge main --no-edit

echo "📤 Pushing V3 to origin..."
git push origin V3

echo "🔙 Switching back to main..."
git checkout main

echo "╔════════════════════════════════════════════════╗"
echo "║  ✨ V3 branch updated successfully!            ║"
echo "╚════════════════════════════════════════════════╝"
