#!/bin/bash
# Script pour générer les fichiers de traduction Flutter

set -e

echo "🌍 Génération des traductions Flutter"
echo "===================================="
echo ""

cd /workspaces/MASLIVE/app

# Télécharger les dépendances si nécessaire
echo "📦 Vérification des dépendances..."
flutter pub get

# Générer les fichiers de localisation
echo "🔄 Génération des fichiers de localisation..."
flutter gen-l10n --arb-dir=lib/l10n

echo ""
echo "✅ Traductions générées avec succès!"
echo ""
echo "Les fichiers suivants ont été créés :"
echo "  - lib/gen/l10n/app_localizations.dart"
echo "  - lib/gen/l10n/app_localizations_*.dart"
echo ""
echo "📝 Utilisation en code :"
echo "  import 'package:flutter_gen/gen_l10n/app_localizations.dart';"
echo "  Text(AppLocalizations.of(context)!.myKey)"
echo ""
