#!/bin/bash

set -e

echo "🚀 Déploiement - Gestion des articles Superadmin"
echo "================================================"

cd /workspaces/MASLIVE

# Phase 1: Vérifier les fichiers créés
echo ""
echo "📋 Vérification des fichiers..."
echo ""

FILES=(
  "app/lib/models/superadmin_article.dart"
  "app/lib/services/superadmin_article_service.dart"
  "app/lib/pages/superadmin_articles_page.dart"
  "app/lib/constants/superadmin_articles_init.dart"
  "SUPERADMIN_ARTICLES_GUIDE.md"
  "SUPERADMIN_ARTICLES_DEPLOYMENT_CHECKLIST.md"
)

for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "✅ $file"
  else
    echo "❌ $file (MANQUANT)"
    exit 1
  fi
done

# Phase 2: Vérifier les modifications
echo ""
echo "🔍 Vérification des modifications..."
echo ""

if grep -q "Mes articles en ligne" app/lib/widgets/commerce/commerce_section_card.dart; then
  echo "✅ commerce_section_card.dart - Ligne 'Mes articles en ligne' ajoutée"
else
  echo "❌ commerce_section_card.dart - Modification non trouvée"
  exit 1
fi

if grep -q "Articles Superadmin" app/lib/admin/admin_main_dashboard.dart; then
  echo "✅ admin_main_dashboard.dart - Tuile 'Articles Superadmin' ajoutée"
else
  echo "❌ admin_main_dashboard.dart - Modification non trouvée"
  exit 1
fi

if grep -q "superadmin_articles" firestore.rules; then
  echo "✅ firestore.rules - Règles pour superadmin_articles ajoutées"
else
  echo "❌ firestore.rules - Modification non trouvée"
  exit 1
fi

if grep -q "initSuperadminArticles" functions/index.js; then
  echo "✅ functions/index.js - Fonction Cloud initSuperadminArticles ajoutée"
else
  echo "❌ functions/index.js - Fonction Cloud non trouvée"
  exit 1
fi

# Phase 3: Git add et commit
echo ""
echo "📝 Git add et commit..."
cd /workspaces/MASLIVE
git add .
git commit -m "feat: gestion articles superadmin (casquette, tshirt, porteclé, bandana)" || echo "Aucun changement à commiter"
git push origin main

echo ""
echo "✅ Commit et push réussis!"

# Phase 4: Build Flutter
echo ""
echo "🔨 Build Flutter web..."
cd /workspaces/MASLIVE/app
flutter pub get > /dev/null 2>&1
echo "✅ flutter pub get"

flutter analyze --no-fatal-warnings --no-fatal-infos > /tmp/analyze.log 2>&1
if [ $? -eq 0 ]; then
  echo "✅ flutter analyze"
else
  echo "⚠️  flutter analyze - Vérifiez /tmp/analyze.log"
fi

# Phase 5: Déploiement Firebase
echo ""
echo "🚀 Déploiement Firebase..."
cd /workspaces/MASLIVE

echo "Déploiement des Cloud Functions et Firestore Rules..."
firebase deploy --only functions,firestore:rules

echo ""
echo "Déploiement du Hosting..."
firebase deploy --only hosting

echo ""
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ DÉPLOIEMENT RÉUSSI!                                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Prochaines étapes:"
echo ""
echo "1️⃣  Initialiser les articles (une seule fois):"
echo "   firebase functions:shell"
echo "   > initSuperadminArticles()"
echo ""
echo "2️⃣  Tester l'accès:"
echo "   - Se connecter en tant que superadmin"
echo "   - Aller dans: Profil → Commerce → 'Mes articles en ligne'"
echo "   - OU Dashboard Admin → Commerce → 'Articles Superadmin'"
echo ""
echo "3️⃣  Vérifier Firestore:"
echo "   - Console: superadmin_articles collection"
echo "   - Vérifier 4 articles visibles après initialisation"
echo ""
echo "📖 Documentation:"
echo "   - SUPERADMIN_ARTICLES_GUIDE.md"
echo "   - SUPERADMIN_ARTICLES_DEPLOYMENT_CHECKLIST.md"
echo ""
