#!/usr/bin/env bash
set -euo pipefail

OWNER="${GITHUB_OWNER:-stef25fwi}"
REPO="${GITHUB_REPO:-MASLIVE}"
BRANCH="${GITHUB_BRANCH:-main}"
TOKEN="${GITHUB_PAT:-${GH_ADMIN_TOKEN:-${GITHUB_TOKEN:-}}}"

if [[ -z "$TOKEN" ]]; then
  echo "GITHUB_PAT ou GH_ADMIN_TOKEN est requis." >&2
  echo "Utilisez un PAT avec permission administration:write sur le repo ${OWNER}/${REPO}." >&2
  exit 1
fi

payload=$(cat <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Flutter Analyze And Test",
      "Functions Test Suite"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
)

api_url="https://api.github.com/repos/${OWNER}/${REPO}/branches/${BRANCH}/protection"

echo "Application de la protection GitHub sur ${OWNER}/${REPO}:${BRANCH}"

curl --fail --silent --show-error \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$api_url" \
  -d "$payload" >/dev/null

echo "Protection de branche appliquée avec succès."