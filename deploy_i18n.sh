#!/bin/bash
# Commit et push de l'implémentation i18n

set -e

echo "📤 Commit et push - Internationalisation"
echo "======================================"
echo ""

cd /workspaces/MASLIVE

# Stage
echo "[1/4] 📝 Stage des fichiers..."
git add -A
echo "✅ Stagés"
echo ""

# Commit
echo "[2/4] 📦 Commit..."
git commit -m "Feat: Add complete i18n system (FR/EN/ES)

- Add intl, get, shared_preferences dependencies
- Create language_service.dart with dynamic language switching
- Implement language_switcher.dart (3 UI variants)
- Add 150+ translations in 3 languages (FR/EN/ES)
- Configure l10n.yaml for Flutter localization
- Create example page and comprehensive documentation
- Persist user language preference with SharedPreferences
- Support system language detection
- Include setup and generation scripts"
echo "✅ Committés"
echo ""

# Push V2
echo "[3/4] 🔄 Push V2 → origin..."
git push origin V2
echo "✅ V2 pushée"
echo ""

# Merge main
echo "[4/4] 🔀 Merge & push main..."
git checkout main
git pull origin main
git merge V2 --no-edit
git push origin main
git checkout V2
echo "✅ Main pushée"
echo ""

echo "════════════════════════════════════"
echo "✅ i18n DÉPLOYÉ SUR MAIN!"
echo "════════════════════════════════════"
echo ""
echo "📝 Pour finir le setup:"
echo "   bash setup_i18n.sh"
echo ""
