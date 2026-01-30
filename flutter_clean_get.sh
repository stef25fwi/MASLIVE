#!/bin/bash
cd /workspaces/MASLIVE/app
echo "🧹 Nettoyage du cache Flutter..."
flutter clean
echo "✅ Cache nettoyé"
echo "📦 Récupération des dépendances..."
flutter pub get
echo "✅ Dépendances récupérées"
