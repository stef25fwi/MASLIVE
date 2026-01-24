#!/bin/bash
# Activation Media Shop V2.1
# Ce script sauvegarde V2.0 et active V2.1

set -e

cd /workspaces/MASLIVE/app/lib/pages

# Backup V2.0
echo "📦 Sauvegarde de V2.0..."
cp media_shop_page.dart media_shop_page_v20_backup.dart

# Activation V2.1
echo "🚀 Activation de V2.1..."
cp media_shop_page_v21.dart media_shop_page.dart

echo "✅ V2.1 activée !"
echo "Fichiers:"
ls -lh media_shop_page*.dart

echo ""
echo "⚠️  IMPORTANT:"
echo "- Tu peux maintenant build et déployer avec: flutter build web --release"
echo "- Pour implémenter le callable Stripe, ajoute dans /functions/index.js:"
echo "  exports.createCheckoutSessionForOrder = functions.https.onCall(async (data, context) => {"
echo "    // Logic avec Stripe SDK"
echo "    return { checkoutUrl: 'https://checkout.stripe.com/...' };"
echo "  });"
