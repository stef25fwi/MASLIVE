#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

commit_message="Fix home map startup style pipeline"
push_flag="--push"
allow_dirty_build="false"
skip_commit="false"

for arg in "$@"; do
  case "$arg" in
    --allow-dirty-build)
      allow_dirty_build="true"
      ;;
    --no-push)
      push_flag=""
      ;;
    --skip-commit)
      skip_commit="true"
      ;;
    *)
      commit_message="$arg"
      ;;
  esac
done

if [[ "$skip_commit" != "true" ]]; then
  echo "==> Commit cible du correctif Home/Mapbox/POI"
  if [[ -n "$push_flag" ]]; then
    bash "$repo_root/scripts/stage_commit_home_map_fix.sh" "$commit_message" "$push_flag"
  else
    bash "$repo_root/scripts/stage_commit_home_map_fix.sh" "$commit_message"
  fi
else
  echo "==> Commit ignore a la demande (--skip-commit)"
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo
  echo "Attention: le depot contient encore des changements locaux non commites."
  git status --short
  echo
  if [[ "$allow_dirty_build" != "true" ]]; then
    echo "Refus du build/deploy pour eviter de publier des changements non voulus."
    echo "Relance avec --allow-dirty-build si tu veux deployer malgre cet etat."
    exit 1
  fi
  echo "Build/deploy force malgre un depot dirty (--allow-dirty-build)."
fi

echo
echo "==> Build + deploy hosting"
bash "$repo_root/build_deploy_now.sh"

echo
echo "OK. Pipeline commit/push/build/deploy termine."
