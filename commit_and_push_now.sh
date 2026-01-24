#!/usr/bin/env bash
# Commit et push les modifications actuelles (script "safe")

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

commit_msg="${1:-}"

echo "📤 COMMIT & PUSH"
echo "================"
echo ""

# Guard: ne jamais committer node_modules
if git ls-files -z "functions/node_modules" "functions/node_modules/**" | head -c 1 | grep -q .; then
	echo "❌ ERREUR: functions/node_modules est suivi par Git."
	echo "   Fix: git rm -r --cached functions/node_modules && git commit -m 'chore: stop tracking functions node_modules'"
	exit 1
fi

# Guard: ne jamais committer de secrets
if git ls-files -z "serviceAccountKey.json" | head -c 1 | grep -q .; then
	echo "❌ ERREUR: serviceAccountKey.json est suivi par Git (secret)."
	echo "   Fix: git rm --cached serviceAccountKey.json && git commit -m 'chore: stop tracking service account key'"
	exit 1
fi
if git ls-files -z "functions/.env" "functions/.env.*" "functions/.runtimeconfig.json" | head -c 1 | grep -q .; then
	echo "❌ ERREUR: un fichier de config secret Functions est suivi par Git (functions/.env* ou functions/.runtimeconfig.json)."
	echo "   Fix: git rm --cached functions/.env* functions/.runtimeconfig.json && git commit -m 'chore: stop tracking functions secrets'"
	exit 1
fi

if [[ -z "$commit_msg" ]]; then
	read -r -p "Message de commit: " commit_msg
fi

if [[ -z "$commit_msg" ]]; then
	echo "❌ Message de commit vide."
	exit 1
fi

echo "📝 Stage des fichiers (en excluant node_modules)..."
git add -A -- . ':!functions/node_modules' ':!functions/node_modules/**'
echo "✅ Stagés"
echo ""

echo "📦 Commit..."
git commit -m "$commit_msg" || {
	echo "ℹ️ Rien à committer."
	exit 0
}
echo "✅ Committé"
echo ""

echo "🔄 Push vers origin (branche courante)..."
current_branch="$(git branch --show-current)"
git push origin "$current_branch"
echo "✅ Push terminé"
echo ""

echo "✅ TERMINÉ!"
