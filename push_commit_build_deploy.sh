#!/usr/bin/env bash
# 🚀 Push + Commit + Build + Deploy (Simple All-in-One Script)
# Usage: ./push_commit_build_deploy.sh "Your commit message"

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to repository root
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# Get commit message from argument or prompt user
commit_msg="${1:-}"

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  🚀 Push + Commit + Build + Deploy               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# STEP 0: Security Checks - Prevent committing secrets
# ============================================================================
echo -e "${YELLOW}[Security Check]${NC} Validating no secrets are staged..."

# Check for node_modules in functions
if git ls-files -z "functions/node_modules" "functions/node_modules/**" 2>/dev/null | head -c 1 | grep -q .; then
    echo -e "${RED}❌ ERROR: functions/node_modules is tracked by Git.${NC}"
    echo "   Fix: git rm -r --cached functions/node_modules"
    exit 1
fi

# Check for service account keys
if git ls-files -z "serviceAccountKey.json" "*firebase-adminsdk*.json" 2>/dev/null | head -c 1 | grep -q .; then
    echo -e "${RED}❌ ERROR: Firebase service account key is tracked by Git (SECURITY RISK).${NC}"
    echo "   Fix: git rm --cached <key-file>.json"
    exit 1
fi

# Check for environment files
if git ls-files -z "functions/.env" "functions/.env.*" "functions/.runtimeconfig.json" 2>/dev/null | head -c 1 | grep -q .; then
    echo -e "${RED}❌ ERROR: Functions environment files are tracked by Git (SECURITY RISK).${NC}"
    echo "   Fix: git rm --cached functions/.env*"
    exit 1
fi

echo -e "${GREEN}✅ Security checks passed${NC}"
echo ""

# ============================================================================
# STEP 1: Clean up temporary files
# ============================================================================
echo -e "${YELLOW}[1/6]${NC} 🧹 Cleaning temporary files..."
rm -f dart_analyze_machine.txt shop_files.zip 2>/dev/null || true
git rm --cached --ignore-unmatch dart_analyze_machine.txt shop_files.zip >/dev/null 2>&1 || true
echo -e "${GREEN}✅ Cleaned${NC}"
echo ""

# ============================================================================
# STEP 2: Stage all changes
# ============================================================================
echo -e "${YELLOW}[2/6]${NC} 📝 Staging all changes..."
git add -A

# Additional security check on staged files
if git diff --cached --name-only -- "serviceAccountKey.json" "*firebase-adminsdk*.json" "functions/.env" "functions/.env.*" "functions/.runtimeconfig.json" 2>/dev/null | head -n 1 | grep -q .; then
    echo -e "${RED}❌ ERROR: Secret files are staged. Cannot proceed.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Staged${NC}"
echo ""

# ============================================================================
# STEP 3: Commit changes
# ============================================================================
if [[ -z "$commit_msg" ]]; then
    read -r -p "📝 Commit message: " commit_msg
fi

if [[ -z "$commit_msg" ]]; then
    commit_msg="chore: automated deployment"
    echo -e "${YELLOW}ℹ️  Using default message: $commit_msg${NC}"
fi

echo -e "${YELLOW}[3/6]${NC} 💾 Committing changes..."
if git commit -m "$commit_msg"; then
    echo -e "${GREEN}✅ Committed: $commit_msg${NC}"
else
    echo -e "${YELLOW}ℹ️  Nothing to commit (working tree clean)${NC}"
    exit 0
fi
echo ""

# ============================================================================
# STEP 4: Push to remote
# ============================================================================
echo -e "${YELLOW}[4/6]${NC} 📤 Pushing to remote..."
current_branch="$(git branch --show-current)"
echo "   Branch: $current_branch"
git push origin "$current_branch"
echo -e "${GREEN}✅ Pushed to origin/$current_branch${NC}"
echo ""

# ============================================================================
# STEP 5: Install dependencies and build
# ============================================================================
echo -e "${YELLOW}[5/6]${NC} 🔨 Building Flutter web application..."

# Install Functions dependencies if package-lock.json exists
if [[ -f "functions/package-lock.json" ]]; then
    echo "   📦 Installing Functions dependencies..."
    (cd functions && npm ci --silent)
else
    echo "   ℹ️  Skipping Functions npm ci (no package-lock.json)"
fi

# Build Flutter web
echo "   📱 Building Flutter web (release mode)..."
cd app
flutter pub get --quiet
flutter build web --release

cd "$repo_root"
echo -e "${GREEN}✅ Build completed${NC}"
echo ""

# ============================================================================
# STEP 6: Deploy to Firebase
# ============================================================================
echo -e "${YELLOW}[6/6]${NC} 🚀 Deploying to Firebase..."
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes
echo -e "${GREEN}✅ Deployed${NC}"
echo ""

# ============================================================================
# SUCCESS
# ============================================================================
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✨ Deployment Successful!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "   • Commit: $commit_msg"
echo "   • Branch: $current_branch"
echo "   • Status: Deployed to Firebase"
echo ""
echo -e "${BLUE}🌐 Your app is live!${NC}"
echo ""
