#!/usr/bin/env bash
# 🚀 Push + Commit + Deploy (Quick Deployment Script)
# Usage: ./push_commit_deploy.sh "Your commit message"
# 
# This script is a faster alternative to push_commit_build_deploy.sh
# It skips the build step for quick deployments of:
# - Firebase configuration changes
# - Functions updates
# - Firestore rules/indexes
# - Documentation updates

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
echo -e "${BLUE}║  🚀 Push + Commit + Deploy (Quick)               ║${NC}"
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
echo -e "${YELLOW}[1/4]${NC} 🧹 Cleaning temporary files..."
rm -f dart_analyze_machine.txt shop_files.zip 2>/dev/null || true
git rm --cached --ignore-unmatch dart_analyze_machine.txt shop_files.zip >/dev/null 2>&1 || true
echo -e "${GREEN}✅ Cleaned${NC}"
echo ""

# ============================================================================
# STEP 2: Stage all changes
# ============================================================================
echo -e "${YELLOW}[2/4]${NC} 📝 Staging all changes..."
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
    commit_msg="chore: quick deployment"
    echo -e "${YELLOW}ℹ️  Using default message: $commit_msg${NC}"
fi

echo -e "${YELLOW}[3/4]${NC} 💾 Committing changes..."
if git commit -m "$commit_msg"; then
    echo -e "${GREEN}✅ Committed: $commit_msg${NC}"
else
    echo -e "${YELLOW}ℹ️  Nothing to commit (working tree clean)${NC}"
    
    # Check if we should still deploy
    read -r -p "Deploy anyway? (y/N): " deploy_anyway
    if [[ ! "$deploy_anyway" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi
echo ""

# ============================================================================
# STEP 4: Push to remote
# ============================================================================
echo -e "${YELLOW}[4/4]${NC} 📤 Pushing to remote..."
current_branch="$(git branch --show-current)"
echo "   Branch: $current_branch"
git push origin "$current_branch"
echo -e "${GREEN}✅ Pushed to origin/$current_branch${NC}"
echo ""

# ============================================================================
# STEP 5: Deploy to Firebase
# ============================================================================
echo -e "${YELLOW}[Deploy]${NC} 🚀 Deploying to Firebase..."
echo ""
echo "Select deployment target:"
echo "  1) Full deployment (hosting + functions + rules)"
echo "  2) Hosting only"
echo "  3) Functions only"
echo "  4) Firestore rules only"
echo "  5) Skip deployment"
echo ""
read -r -p "Choice (1-5): " deploy_choice

case "$deploy_choice" in
    1)
        echo -e "${BLUE}Deploying: hosting, functions, firestore rules & indexes${NC}"
        firebase deploy --only hosting,functions,firestore:rules,firestore:indexes
        ;;
    2)
        echo -e "${BLUE}Deploying: hosting only${NC}"
        firebase deploy --only hosting
        ;;
    3)
        echo -e "${BLUE}Deploying: functions only${NC}"
        firebase deploy --only functions
        ;;
    4)
        echo -e "${BLUE}Deploying: firestore rules & indexes${NC}"
        firebase deploy --only firestore:rules,firestore:indexes
        ;;
    5)
        echo -e "${YELLOW}Skipping deployment${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice. Skipping deployment.${NC}"
        ;;
esac

echo ""
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
echo "   • Status: Pushed & Deployed"
echo ""
echo -e "${BLUE}💡 Tip: For full builds, use ./push_commit_build_deploy.sh${NC}"
echo ""
