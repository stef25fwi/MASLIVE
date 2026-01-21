#!/bin/bash
# Setup complet pour l'internationalisation Flutter

set -e

echo "🌍 Setup Internationalisation (i18n)"
echo "===================================="
echo ""

cd /workspaces/MASLIVE/app

# 1. Mettre à jour les dépendances
echo "[1/3] 📦 Mise à jour des dépendances..."
flutter pub get
echo "✅ Dépendances à jour"
echo ""

# 2. Générer les fichiers de localisation
echo "[2/3] 🔄 Génération des fichiers de localisation..."
flutter gen-l10n --arb-dir=lib/l10n
echo "✅ Fichiers générés dans lib/gen/l10n/"
echo ""

# 3. Vérifier les fichiers générés
echo "[3/3] ✅ Vérification des fichiers..."
if [ -f "lib/gen/l10n/app_localizations.dart" ]; then
  echo "✅ app_localizations.dart généré"
else
  echo "❌ Erreur: app_localizations.dart non trouvé"
  exit 1
fi

echo ""
echo "════════════════════════════════════"
echo "🎉 Setup i18n COMPLÉTÉ!"
echo "════════════════════════════════════"
echo ""
echo "📝 Prochaines étapes:"
echo "  1. Vérifiez que main.dart a:"
echo "     - import 'l10n/app_localizations.dart';"
echo "     - locale: Get.find<LanguageService>().locale"
echo "     - localizationsDelegates: AppLocalizations.localizationsDelegates"
echo "     - supportedLocales: AppLocalizations.supportedLocales"
echo ""
echo "  2. Lancez l'app:"
echo "     flutter run"
echo ""
echo "  3. Testez le sélecteur de langue:"
echo "     - Icône 🌐 dans l'AppBar"
echo "     - Ou LanguageSelectionPage()"
echo ""
echo "📚 Documentation: app/I18N_GUIDE.md"
echo ""
