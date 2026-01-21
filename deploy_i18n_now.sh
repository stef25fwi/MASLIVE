#!/bin/bash

echo "🌐 DÉPLOIEMENT i18n SUR MAIN"
echo "============================"

# Étape 1: Stage tous les fichiers
echo "[1/5] 📝 Stage des fichiers..."
git add -A
echo "✅ Fichiers stagés"

# Étape 2: Commit
echo "[2/5] 📦 Commit des changements i18n..."
git commit -m "Feat: Add complete i18n system (FR/EN/ES) with language switcher

- Add 150+ translations for French, English, Spanish
- Implement LanguageService with GetX state management
- Add 3 UI language selector variants (icon, page, dialog)
- Configure SharedPreferences for language persistence
- Enable flutter generate in pubspec.yaml
- Add intl, get, shared_preferences dependencies
- Create comprehensive documentation (I18N_GUIDE.md, etc.)
- Add automation scripts for setup and deployment"

echo "✅ Commit créé"

# Étape 3: Push V2
echo "[3/5] 🔄 Push V2 → origin..."
git push origin V2
echo "✅ V2 pushée"

# Étape 4: Merge dans main
echo "[4/5] 🔀 Merge dans main..."
git checkout main
git pull origin main
git merge V2 -m "Merge V2: i18n system complete"
echo "✅ Merge effectué"

# Étape 5: Push main
echo "[5/5] 🚀 Push main → origin..."
git push origin main
echo "✅ Main pushée"

# Retour sur V2
git checkout V2

echo ""
echo "════════════════════════════"
echo "✅ i18n DÉPLOYÉ SUR MAIN!"
echo "════════════════════════════"
echo ""
echo "📝 Fichiers ajoutés:"
echo "   - app/lib/l10n/app_*.arb (3 langues)"
echo "   - app/lib/services/language_service.dart"
echo "   - app/lib/widgets/language_switcher.dart"
echo "   - app/lib/pages/language_example_page.dart"
echo "   - app/l10n.yaml"
echo "   - Documentation complète"
echo "   - Scripts d'automatisation"
echo ""
echo "🎯 Prochaine étape:"
echo "   cd app && flutter gen-l10n && flutter run"
