#!/bin/bash
# Script de vérification des installations - Flutter SDK et Firebase CLI

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Vérification: Flutter SDK et Firebase CLI                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Node.js
echo "🔍 Node.js"
if command -v node &> /dev/null; then
    VERSION=$(node --version)
    echo -e "  ${GREEN}✅${NC} Node.js: $VERSION"
else
    echo -e "  ${RED}❌${NC} Node.js: Non installé"
fi

# Check npm
echo ""
echo "🔍 npm"
if command -v npm &> /dev/null; then
    VERSION=$(npm --version)
    echo -e "  ${GREEN}✅${NC} npm: v$VERSION"
else
    echo -e "  ${RED}❌${NC} npm: Non installé"
fi

# Check Firebase CLI
echo ""
echo "🔍 Firebase CLI"
if command -v firebase &> /dev/null; then
    VERSION=$(firebase --version)
    LOCATION=$(which firebase)
    echo -e "  ${GREEN}✅${NC} Firebase CLI: $VERSION"
    echo -e "  ${GREEN}✅${NC} Location: $LOCATION"
    echo -e "  ${GREEN}✅${NC} OPÉRATIONNEL"
else
    echo -e "  ${RED}❌${NC} Firebase CLI: Non installé"
    echo ""
    echo "  Pour installer:"
    echo "  npm install -g firebase-tools"
fi

# Check Flutter
echo ""
echo "🔍 Flutter SDK"
if command -v flutter &> /dev/null; then
    VERSION=$(flutter --version 2>&1 | head -1)
    LOCATION=$(which flutter)
    echo -e "  ${GREEN}✅${NC} Flutter: Disponible"
    echo -e "  ${GREEN}✅${NC} Location: $LOCATION"
    echo -e "  ${GREEN}✅${NC} Version: $VERSION"
    echo ""
    echo "  Status complet:"
    flutter doctor -v 2>&1 | head -30
else
    if [ -d "/home/runner/flutter" ]; then
        echo -e "  ${YELLOW}⚠️${NC}  Flutter: Repository cloné mais non configuré"
        echo -e "  ${YELLOW}⚠️${NC}  Location: /home/runner/flutter"
        echo ""
        echo "  Pour configurer:"
        echo "  export PATH=\"\$PATH:/home/runner/flutter/bin\""
        echo "  flutter doctor"
    else
        echo -e "  ${RED}❌${NC} Flutter SDK: Non installé"
        echo ""
        echo "  Pour installer:"
        echo "  git clone https://github.com/flutter/flutter.git -b stable"
        echo "  export PATH=\"\$PATH:\`pwd\`/flutter/bin\""
        echo "  flutter doctor"
    fi
fi

# Check Dart
echo ""
echo "🔍 Dart SDK"
if command -v dart &> /dev/null; then
    VERSION=$(dart --version 2>&1)
    echo -e "  ${GREEN}✅${NC} Dart: $VERSION"
else
    echo -e "  ${YELLOW}⚠️${NC}  Dart: Non disponible (inclus dans Flutter)"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Résumé                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Firebase CLI check
if command -v firebase &> /dev/null; then
    echo -e "${GREEN}✅ Firebase CLI${NC}: PRÊT à utiliser"
else
    echo -e "${RED}❌ Firebase CLI${NC}: Installation requise"
fi

# Flutter check
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}✅ Flutter SDK${NC}: Installé et configuré"
elif [ -d "/home/runner/flutter" ]; then
    echo -e "${YELLOW}⚠️  Flutter SDK${NC}: Disponible mais nécessite configuration PATH"
    echo "    Solution: Utiliser GitHub Actions workflow (recommandé)"
else
    echo -e "${RED}❌ Flutter SDK${NC}: Installation requise"
    echo "    Solution: Utiliser GitHub Actions workflow (recommandé)"
fi

echo ""
echo "📖 Voir INSTALLATION_FLUTTER_FIREBASE.md pour plus de détails"
echo ""
