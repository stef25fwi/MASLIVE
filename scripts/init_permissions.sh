#!/bin/bash

# Script d'initialisation du système de rôles et permissions pour MASLIVE
# Ce script déploie les règles Firestore et les Cloud Functions

set -e

echo "=========================================="
echo "Initialisation du système de permissions"
echo "=========================================="
echo ""

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "firebase.json" ]; then
    echo "❌ Erreur: firebase.json non trouvé"
    echo "   Veuillez exécuter ce script depuis la racine du projet MASLIVE"
    exit 1
fi

echo "📝 Étape 1/3: Déploiement des règles Firestore..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ Règles Firestore déployées avec succès"
else
    echo "❌ Échec du déploiement des règles Firestore"
    exit 1
fi

echo ""
echo "☁️  Étape 2/3: Déploiement des Cloud Functions..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo "✅ Cloud Functions déployées avec succès"
else
    echo "❌ Échec du déploiement des Cloud Functions"
    exit 1
fi

echo ""
echo "📦 Étape 3/3: Installation des dépendances Flutter..."
cd app
flutter pub get

if [ $? -eq 0 ]; then
    echo "✅ Dépendances Flutter installées"
else
    echo "❌ Échec de l'installation des dépendances"
    exit 1
fi

cd ..

echo ""
echo "=========================================="
echo "✅ Initialisation terminée avec succès!"
echo "=========================================="
echo ""
echo "📋 Prochaines étapes:"
echo ""
echo "1. Créer un premier super administrateur:"
echo "   - Allez dans la console Firebase"
echo "   - Collection 'users'"
echo "   - Trouvez votre utilisateur"
echo "   - Ajoutez les champs:"
echo "     • role: \"superAdmin\""
echo "     • isAdmin: true"
echo ""
echo "2. Initialiser les rôles dans Firestore:"
echo "   - Depuis l'application Flutter, appelez:"
echo "     PermissionService.instance.initializeDefaultRoles()"
echo "   - Ou utilisez la Cloud Function 'initializeRoles'"
echo ""
echo "3. Documentation complète:"
echo "   - Consultez ROLES_AND_PERMISSIONS.md"
echo ""
echo "=========================================="
