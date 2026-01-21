#!/bin/bash

# Script pour nettoyer complètement et rebuilder l'app web

echo "🧹 Nettoyage du cache Flutter..."
cd /workspaces/MASLIVE/app
flutter clean

echo "📦 Installation des dépendances..."
flutter pub get

echo "🏗️ Build web en mode release..."
flutter build web --release

echo "🔥 Déploiement sur Firebase Hosting..."
cd ..
firebase deploy --only hosting

echo "✅ Terminé ! Vérifiez l'app sur votre URL Firebase Hosting"
echo "💡 Astuce: Utilisez Ctrl+Shift+R dans le navigateur pour forcer le rechargement sans cache"
