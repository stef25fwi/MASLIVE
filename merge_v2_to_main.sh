#!/bin/bash
# Merge V2 vers main avec commit des changements locaux

set -e

echo "🔀 MERGE V2 → MAIN"
echo "=================="
echo ""

# Commit changes locaux si nécessaire
echo "[1/6] 📝 Commit changements locaux..."
git add -A
if git diff --staged --quiet; then
  echo "Aucun changement à commiter"
else
  git commit -m "chore: update tasks.json and scripts"
  echo "✅ Changements commités"
fi
echo ""

# Checkout main
echo "[2/6] 📂 Checkout main..."
git checkout main

# Pull latest
echo "[3/6] ⬇️  Pull main..."
git pull origin main

# Merge V2
echo "[4/6] 🔀 Merge V2..."
git merge V2 -m "Merge branch 'V2' into main"

# Push main
echo "[5/6] ⬆️  Push main..."
git push origin main

# Retour V2
echo "[6/6] ↩️  Retour V2..."
git checkout V2

echo ""
echo "✅ V2 mergée dans main !"
