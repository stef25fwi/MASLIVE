#!/bin/bash
cd /workspaces/MASLIVE
echo "Committing changes..."
git add -A
git commit -m "chore(deps): phased upgrade (analyzer + build + web)"
echo ""
echo "Pushing to deps/async-update..."
git push origin deps/async-update
echo ""
echo "✅ Done!"
