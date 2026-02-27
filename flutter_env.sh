#!/usr/bin/env bash
# Helper: ensure Flutter SDK from this repo is on PATH.
# Usage: source /workspaces/MASLIVE/flutter_env.sh

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If flutter is already available, keep it.
if command -v flutter >/dev/null 2>&1; then
  return 0
fi

# Prefer the repo-local SDK (commonly present in this workspace).
if [[ -x "$repo_root/.flutter_sdk/bin/flutter" ]]; then
  export PATH="$repo_root/.flutter_sdk/bin:$PATH"
  return 0
fi

echo "❌ flutter introuvable. Attendu: flutter sur PATH ou $repo_root/.flutter_sdk/bin/flutter" >&2
return 127
