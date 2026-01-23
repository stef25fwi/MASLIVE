#!/bin/bash
# Commit et push les modifications actuelles

set -e

echo "📤 COMMIT & PUSH"
echo "================"
echo ""

# Stage
echo "📝 Stage des fichiers..."
git add -A
echo "✅ Stagés"
echo ""

# Commit
echo "📦 Commit..."
git commit -m "feat(shop): styles filtres (contours + ombres) et bouton retour header\n\n- RainbowHeader: ajout bouton retour haut-gauche (pop ou route)\n- Boutique: contours 1.5px gris + ombre douce 8px sur tuiles filtres\n- Focus: bordures colorées pour meilleure interactivité\n- Tuiles: Pays, Événement, Groupe, Photographe, Tri, Date"
echo "✅ Committés"
echo ""

# Push
echo "🔄 Push vers origin main..."
git push origin main
echo "✅ Main pushée"
echo ""

echo "✅ TERMINÉ!"
