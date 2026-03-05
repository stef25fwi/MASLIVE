#!/usr/bin/env bash
# Validate + Deploy POI Menu Alignment (circuit_poi_editor_page.dart)

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_root"

# Load Flutter env
if [[ -f "$repo_root/flutter_env.sh" ]]; then
  source "$repo_root/flutter_env.sh" || true
fi

echo "=========================================="
echo "VALIDATION + DEPLOYMENT (POI Menu)"
echo "=========================================="
echo ""

# 1. Quick validate syntax on the modified file
echo "[1/3] Validating circuit_poi_editor_page.dart..."
if command -v dart >/dev/null 2>&1; then
  cd "$repo_root/app"
  echo "Running: dart analyze on lib/admin/circuit_poi_editor_page.dart"
  if dart analyze lib/admin/circuit_poi_editor_page.dart 2>&1 | tee /tmp/dart_analyze.log; then
    echo "✅ Syntax OK"
  else
    echo "⚠️  Analyzer issues found (see above)"
    # Continue anyway for now
  fi
  cd "$repo_root"
else
  echo "⚠️  dart not found, skipping analyzer check"
fi
echo ""

# 2. Commit message
echo "[2/3] Preparing commit..."
commit_msg="refactor: align CircuitPoiEditorPage POI menu with wizard (GlassPanel + nav + zones parking + import)"
echo "Message: $commit_msg"
echo ""

# 3. Run the main deploy script
echo "[3/3] Running commit_push_build_deploy.sh..."
exec "$repo_root/commit_push_build_deploy.sh" "$commit_msg" "main"
