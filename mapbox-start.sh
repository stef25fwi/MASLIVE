#!/bin/bash

# 🎯 MAPBOX ACCESS TOKEN - START HERE
# This script provides an interactive menu for Mapbox configuration

set -e

PROJECT_ROOT="/workspaces/MASLIVE"

clear
cat << "EOF"

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     🗺️  MAPBOX ACCESS TOKEN CONFIGURATION - MASLIVE            ║
║                                                                ║
║     Quick Start Guide                                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

EOF

echo ""
echo "📋 What would you like to do?"
echo ""
echo "  1️⃣  Setup Mapbox token (FIRST TIME)"
echo "  2️⃣  Build with Mapbox"
echo "  3️⃣  Build + Deploy to Firebase"
echo "  4️⃣  View quick start guide"
echo "  5️⃣  View complete documentation"
echo "  6️⃣  Troubleshoot Mapbox issues"
echo "  7️⃣  Exit"
echo ""

read -p "Choose option (1-7): " choice

case $choice in
  1)
    echo ""
    echo "🚀 Starting Mapbox token configuration..."
    echo ""
    bash "$PROJECT_ROOT/scripts/setup_mapbox.sh"
    ;;
  2)
    echo ""
    echo "🔨 Building with Mapbox token..."
    echo ""
    bash "$PROJECT_ROOT/scripts/build_with_mapbox.sh"
    ;;
  3)
    echo ""
    echo "📤 Building and deploying to Firebase..."
    echo ""
    bash "$PROJECT_ROOT/scripts/deploy_with_mapbox.sh"
    ;;
  4)
    echo ""
    echo "📖 Quick Start Guide:"
    echo ""
    less "$PROJECT_ROOT/MAPBOX_SETUP_QUICK.md" || cat "$PROJECT_ROOT/MAPBOX_SETUP_QUICK.md"
    ;;
  5)
    echo ""
    echo "📚 Complete Documentation:"
    echo ""
    echo "  - MAPBOX_INDEX.md (Navigation)"
    echo "  - MAPBOX_TOKEN_SETUP.md (Detailed)"
    echo "  - MAPBOX_CONFIGURATION.md (Reference)"
    echo "  - MAPBOX_DEMO_USAGE.md (Examples)"
    echo ""
    ;;
  6)
    echo ""
    echo "🔍 Troubleshooting:"
    echo ""
    echo "Common issues and solutions:"
    echo ""
    echo "❌ 'Token manquant'"
    echo "   → Run: bash scripts/setup_mapbox.sh"
    echo ""
    echo "❌ 'Carte blanche (no map displayed)'"
    echo "   → Check token is valid on mapbox.com"
    echo "   → Verify token starts with 'pk_'"
    echo "   → Try: flutter clean && flutter pub get"
    echo ""
    echo "❌ 'Unauthorized access token'"
    echo "   → Go to: https://account.mapbox.com/tokens/"
    echo "   → Check token scopes are correct"
    echo "   → Regenerate if needed"
    echo ""
    echo "❌ '.env was committed to git'"
    echo "   → Run: git rm --cached .env"
    echo "   → Commit: git commit -m 'fix: remove .env'"
    echo ""
    ;;
  7)
    echo ""
    echo "👋 Goodbye! Remember:"
    echo "   1. Setup: bash scripts/setup_mapbox.sh"
    echo "   2. Deploy: bash scripts/deploy_with_mapbox.sh"
    echo ""
    exit 0
    ;;
  *)
    echo ""
    echo "❌ Invalid option. Please choose 1-7"
    exit 1
    ;;
esac

echo ""
echo "✅ Done!"
echo ""
EOF
