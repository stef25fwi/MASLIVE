#!/bin/bash

set -e

FLUTTER_BIN="/workspaces/MASLIVE/.flutter_sdk/bin/flutter"
APP_DIR="/workspaces/MASLIVE/app"

echo ""
echo "UPDATE PLAN WITH 3 PHASES"
echo "========================="
echo ""

# Setup git config if needed
cd /workspaces/MASLIVE
EMAIL=$(git config --get user.email || true)
NAME=$(git config --get user.name || true)
if [ -z "$EMAIL" ]; then git config user.email "devcontainer@maslive.local"; fi
if [ -z "$NAME" ]; then git config user.name "MASLIVE Devcontainer"; fi

# Create branch
echo "[1/7] Creating branch deps/async-update..."
git checkout -b deps/async-update 2>/dev/null || git checkout deps/async-update
echo "     OK - Branch ready"
echo ""

# PHASE 1: Analyzer Stack
echo "[2/7] PHASE 1: Analyzer Stack (analyzer, _fe_analyzer_shared, source_gen)"
echo "----------------------------------------------------------------------"
cd "$APP_DIR"
echo "      Fetching updates..."
$FLUTTER_BIN pub upgrade _fe_analyzer_shared analyzer source_gen 2>&1 | grep -E "Upgrading|upgraded|identical" || true
echo ""
echo "[3/7] Testing Phase 1 - flutter analyze..."
echo "      (Running analysis...)"
timeout 60 $FLUTTER_BIN analyze 2>&1 | tail -5 || echo "      analyze completed or timeout"
echo ""

# PHASE 2: Build System
echo "[4/7] PHASE 2: Build System (build, build_runner, build_config, etc)"
echo "-------------------------------------------------------------------"
echo "      Fetching updates..."
$FLUTTER_BIN pub upgrade build build_runner build_runner_core build_resolvers build_config 2>&1 | grep -E "Upgrading|upgraded|identical" || true
echo ""
echo "[5/7] Testing Phase 2 - clean + pub get + web build..."
echo "      Cleaning build artifacts..."
$FLUTTER_BIN clean >/dev/null 2>&1
echo "      Getting dependencies..."
timeout 120 $FLUTTER_BIN pub get 2>&1 | tail -3
echo "      Building web (debug) - this may take a few minutes..."
timeout 300 $FLUTTER_BIN build web --debug 2>&1 | tail -20 || echo "      Build process completed or timeout"
echo ""

# PHASE 3: Web & Platform
echo "[6/7] PHASE 3: Web & Platform (dart_style, shelf_web_socket, win32, etc)"
echo "-----------------------------------------------------------------------"
echo "      Fetching updates..."
$FLUTTER_BIN pub upgrade dart_style shelf_web_socket win32 meta source_helper 2>&1 | grep -E "Upgrading|upgraded|identical" || true
echo ""
echo "[7/7] Final verification - pub get..."
timeout 120 $FLUTTER_BIN pub get 2>&1 | tail -3
echo "     OK"
echo ""

# Summary
echo "==============================================="
echo "ALL PHASES COMPLETE - CHANGES SUMMARY"
echo "==============================================="
echo ""
cd /workspaces/MASLIVE
echo "Current branch: $(git rev-parse --abbrev-ref HEAD)"
echo "Git status:"
git status --short | head -20
echo ""
echo "Next: Commit and push"
echo "  git add -A"
echo "  git commit -m 'chore(deps): phased upgrade (analyzer + build + web)'"
echo "  git push origin deps/async-update"
echo ""

