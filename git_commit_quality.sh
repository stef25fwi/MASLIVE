#!/bin/bash
cd /workspaces/MASLIVE

git add -A

git commit -m "refactor: nettoyage code qualité (print + deprecated API)

- ~220 print() → debugPrint/developer.log  
- ~35 Color API deprecated → .withValues()
- Simplification migrate_images.dart
- Functions: firebase-functions/v1 + types Sharp
- Réduction: 314 → 60 analyzer issues (81%)"

echo ""
echo "✅ Commit réussi!"
echo ""

# Afficher le dernier commit
git log -1 --oneline --decorate
