#!/usr/bin/env bash
# Commit + Push + Build + Deploy (script "safe")

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

commit_msg="${1:-}"

echo "📤 COMMIT + PUSH + BUILD + DEPLOY"
echo "==============================="
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

# Guard: ne jamais committer une clé Firebase Admin SDK
if git ls-files -z -- "*firebase-adminsdk*.json" | head -c 1 | grep -q .; then
	echo "❌ ERREUR: un fichier *firebase-adminsdk*.json est suivi par Git (secret)."
	echo "   Fix: git rm --cached <fichier>.json && git commit -m 'chore: stop tracking firebase admin sdk key'"
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

echo "[0/5] 🧹 Nettoyage artefacts locaux..."
rm -f dart_analyze_machine.txt shop_files.zip 2>/dev/null || true
git rm --cached --ignore-unmatch dart_analyze_machine.txt shop_files.zip >/dev/null 2>&1 || true
echo "✅ Artefacts nettoyés"
echo ""

echo "[1/5] 📝 Stage des fichiers (en excluant node_modules)..."
git add -A

# Guard: ne jamais stager de secrets (même si présents en untracked)
if git diff --cached --name-only -- "serviceAccountKey.json" | head -n 1 | grep -q .; then
	echo "❌ ERREUR: serviceAccountKey.json est stagé (secret)."
	echo "   Fix: git reset -- serviceAccountKey.json && ajoute-le à .gitignore"
	exit 1
fi
if git diff --cached --name-only -- "*firebase-adminsdk*.json" | head -n 1 | grep -q .; then
	echo "❌ ERREUR: un fichier *firebase-adminsdk*.json est stagé (secret)."
	echo "   Fix: git reset -- <fichier>.json && ajoute-le à .gitignore"
	exit 1
fi
if git diff --cached --name-only -- "functions/.env" "functions/.env."* "functions/.runtimeconfig.json" | head -n 1 | grep -q .; then
	echo "❌ ERREUR: un fichier secret Functions est stagé (functions/.env* ou functions/.runtimeconfig.json)."
	echo "   Fix: git reset -- functions/.env functions/.env.* functions/.runtimeconfig.json && ajoute-les à .gitignore"
	exit 1
fi
echo "✅ Stagés"
echo ""

echo "[2/5] 📦 Commit..."
git commit -m "$commit_msg" || {
	echo "ℹ️ Rien à committer."
	exit 0
}
echo "✅ Committé"
echo ""

echo "[3/5] 🔄 Push vers origin (branche courante)..."
current_branch="$(git branch --show-current)"
git push origin "$current_branch"
echo "✅ Push terminé"
echo ""

echo "[4/5] 🧰 Dépendances Functions (npm ci)..."
if [[ -f "functions/package-lock.json" ]]; then
	(cd functions && npm ci)
else
	echo "ℹ️ functions/package-lock.json absent: skip npm ci"
fi
echo "✅ OK"
echo ""

echo "[5/5] 🚀 Build Flutter web + Deploy Firebase..."
(cd app && flutter pub get && flutter build web --release)
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes
echo "✅ Déployé"
echo ""

echo "════════════════════════════"
echo "✅ LIVRAISON TERMINÉE"
echo "════════════════════════════"
