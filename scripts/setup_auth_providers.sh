#!/bin/bash

set -e

echo "🔐 Configuration des fournisseurs d'authentification (Google & Apple)"
echo "=================================================================="
echo ""

PROJECT_ID="maslive"
PACKAGE_NAME="com.example.masslive"
ANDROID_DIR="/workspaces/MASLIVE/app/android"
IOS_DIR="/workspaces/MASLIVE/app/ios"

echo "📱 1. Configuration Android - Google Sign-In"
echo "-------------------------------------------"
echo "Obtention du SHA-1 et SHA-256 du keystore debug..."
echo ""

cd "$ANDROID_DIR"

# Obtenir les signatures
if ./gradlew signingReport 2>/dev/null | grep -A 10 "Variant: debug" > /tmp/signing_report.txt; then
    SHA1=$(grep "SHA1:" /tmp/signing_report.txt | awk '{print $2}')
    SHA256=$(grep "SHA-256:" /tmp/signing_report.txt | awk '{print $2}')
    
    echo "✅ Signatures obtenues:"
    echo "   SHA-1:   $SHA1"
    echo "   SHA-256: $SHA256"
    echo ""
    echo "📋 Actions requises:"
    echo "   1. Allez sur: https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
    echo "   2. Sélectionnez l'app Android"
    echo "   3. Ajoutez ces empreintes SHA dans 'Empreintes de certificat SHA'"
    echo "   4. Téléchargez le nouveau google-services.json"
    echo "   5. Remplacez: app/android/app/google-services.json"
    echo ""
else
    echo "⚠️  Impossible d'obtenir le signingReport"
    echo "   Exécutez manuellement: cd android && ./gradlew signingReport"
fi

echo ""
echo "🍎 2. Configuration iOS - Google Sign-In"
echo "----------------------------------------"
echo "📋 Actions requises:"
echo "   1. Téléchargez GoogleService-Info.plist depuis:"
echo "      https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
echo "   2. Placez-le dans: app/ios/Runner/"
echo "   3. Le REVERSED_CLIENT_ID est déjà configuré dans Info.plist"
echo ""

echo ""
echo "🔑 3. Configuration Firebase Authentication"
echo "--------------------------------------------"
echo "📋 Actions requises:"
echo "   1. Allez sur: https://console.firebase.google.com/project/$PROJECT_ID/authentication/providers"
echo "   2. Activez 'Google' comme fournisseur"
echo "   3. Activez 'Apple' comme fournisseur"
echo ""
echo "   Pour Apple Sign-In, vous aurez besoin de:"
echo "   - Service ID (créez-le sur: https://developer.apple.com/account/resources/identifiers/list/serviceId)"
echo "   - Team ID"
echo "   - Key ID et fichier .p8 (créez une clé sur: https://developer.apple.com/account/resources/authkeys/list)"
echo ""

echo ""
echo "🍏 4. Configuration Xcode - Apple Sign-In"
echo "------------------------------------------"
echo "📋 Actions requises:"
echo "   1. Ouvrez le projet: open $IOS_DIR/Runner.xcworkspace"
echo "   2. Sélectionnez Runner → Signing & Capabilities"
echo "   3. Cliquez '+ Capability' → Ajoutez 'Sign in with Apple'"
echo "   4. Configurez l'App ID sur: https://developer.apple.com/account/resources/identifiers/list"
echo ""

echo ""
echo "🌐 5. Configuration Web (déjà déployé)"
echo "---------------------------------------"
echo "✅ Vérifiez que ces domaines sont autorisés:"
echo "   https://console.firebase.google.com/project/$PROJECT_ID/authentication/settings"
echo "   - maslive.web.app"
echo "   - maslive.firebaseapp.com"
echo "   - localhost (pour le développement)"
echo ""

echo ""
echo "📝 6. Test de configuration"
echo "----------------------------"
echo "Une fois tout configuré, testez avec:"
echo "   cd /workspaces/MASLIVE/app"
echo "   flutter run -d chrome  # Pour tester sur web"
echo "   flutter run -d <device>  # Pour tester sur mobile"
echo ""

echo ""
echo "✅ Script terminé!"
echo "=================================================================="
echo "⚠️  Note: Les étapes ci-dessus nécessitent une configuration manuelle"
echo "    dans Firebase Console, Apple Developer Portal, et Xcode."
echo ""
