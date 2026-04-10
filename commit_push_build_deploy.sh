#!/usr/bin/env bash
# Commit + Push + Build + Deploy (script "safe")

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

is_placeholder_git_identity() {
	local value="${1:-}"
	case "$value" in
		""|TON_EMAIL_GITHUB_ICI|TON_NOM_GITHUB_ICI|YOUR_GITHUB_EMAIL_HERE|YOUR_GITHUB_NAME_HERE|your@email.com|example@example.com|changeme)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

is_valid_git_email() {
	local value="${1:-}"
	[[ "$value" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

# Ensure git identity exists (useful in devcontainers)
NAME="$(git config --get user.name || true)"
EMAIL="$(git config --get user.email || true)"

if is_placeholder_git_identity "$NAME"; then
	git config user.name "MASLIVE Devcontainer"
	NAME="MASLIVE Devcontainer"
fi

if is_placeholder_git_identity "$EMAIL" || ! is_valid_git_email "$EMAIL"; then
	if [[ -n "$EMAIL" ]]; then
		echo "⚠️ user.email Git invalide ($EMAIL) -> fallback devcontainer"
	fi
	git config user.email "devcontainer@maslive.local"
	EMAIL="devcontainer@maslive.local"
fi

commit_msg="${1:-}"
push_branch_arg="${2:-}"

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
if git ls-files -z "functions/.env" "functions/.env.*" "functions/.runtimeconfig.json" | tr '\0' '\n' | grep -v '\.env\.example' | head -c 1 | grep -q .; then
	echo "❌ ERREUR: un fichier de config secret Functions est suivi par Git (functions/.env* ou functions/.runtimeconfig.json)."
	echo "   Fix: git rm --cached functions/.env* functions/.runtimeconfig.json && git commit -m 'chore: stop tracking functions secrets'"
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
if git diff --cached --name-only -- "functions/.env" "functions/.env."* "functions/.runtimeconfig.json" | grep -v '\.env\.example' | head -n 1 | grep -q .; then
	echo "❌ ERREUR: un fichier secret Functions est stagé (functions/.env* ou functions/.runtimeconfig.json)."
	echo "   Fix: git reset -- functions/.env functions/.env.* functions/.runtimeconfig.json && ajoute-les à .gitignore"
	exit 1
fi
echo "✅ Stagés"
echo ""

if git diff --cached --quiet; then
	echo "[2/5] 📦 Commit..."
	echo "ℹ️ Rien à committer. On continue (build+deploy)."
	echo ""
else
	if [[ -z "$commit_msg" ]]; then
		read -r -p "Message de commit: " commit_msg
	fi

	if [[ -z "$commit_msg" ]]; then
		echo "❌ Message de commit vide."
		exit 1
	fi

	echo "[2/5] 📦 Commit..."
	commit_log="$(mktemp)"
	if git commit -m "$commit_msg" >"$commit_log" 2>&1; then
		cat "$commit_log"
	else
		cat "$commit_log"
		if grep -Eqi 'gpg failed to sign the data|failed to write commit object|Author is invalid' "$commit_log"; then
			echo "⚠️ Signature Git refusée, nouvelle tentative sans GPG pour ce commit..."
			git -c commit.gpgsign=false commit -m "$commit_msg"
		else
			rm -f "$commit_log"
			exit 1
		fi
	fi
	rm -f "$commit_log"
	echo "✅ Committé"
	echo ""
fi

if [[ -n "$push_branch_arg" ]]; then
	push_branch="$push_branch_arg"
else
	push_branch="$(git branch --show-current)"
fi

echo "[3/5] 🔄 Push vers origin ($push_branch)..."
git push origin "$push_branch"
echo "✅ Push terminé"
echo ""

echo "[4/5] 🧰 Dépendances Functions (npm ci)..."
if [[ -f "functions/package-lock.json" ]]; then
	(cd functions && npm ci --omit=dev)
else
	echo "ℹ️ functions/package-lock.json absent: skip npm ci"
fi
echo "✅ OK"
echo ""

echo "[5/5] 🚀 Build Flutter web + Deploy Firebase..."

ensure_flutter() {
	if command -v flutter >/dev/null 2>&1; then
		echo "🧩 Flutter détecté: $(command -v flutter)"
		return 0
	fi

	# Prefer repo-local Flutter if present.
	local flutter_dir="$repo_root/.flutter_sdk"
	if [[ ! -d "$flutter_dir" ]]; then
		echo "⬇️  Flutter manquant. Installation locale dans $flutter_dir ..."
		git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$flutter_dir"
	fi

	export PATH="$flutter_dir/bin:$PATH"
	echo "🧩 Flutter (local) activé: $(command -v flutter)"

	# Evite prompts (analytics) + assure le support web.
	flutter config --no-analytics >/dev/null 2>&1 || true
	flutter config --enable-web >/dev/null 2>&1 || true
	flutter --version >/dev/null
}

ensure_flutter

# Mapbox token requis pour la home (carte) en production.
{ [ -f "/workspaces/MASLIVE/.env" ] && source "/workspaces/MASLIVE/.env"; } 2>/dev/null || true
TOKEN=${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}
STRIPE_PREMIUM_ARGS=()
if [[ -z "$TOKEN" ]]; then
	echo "❌ ERREUR: token Mapbox manquant (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN / MAPBOX_TOKEN)."
	echo "➡️  Utilise la tâche VS Code: 'MASLIVE: 🗺️ Set Mapbox token (.env)' puis relance."
	exit 1
fi
echo "🗺️  Token Mapbox détecté: OK (redacted)"
if [[ -n "${STRIPE_PREMIUM_MONTHLY_PRICE_ID:-}" && -n "${STRIPE_PREMIUM_YEARLY_PRICE_ID:-}" ]]; then
	STRIPE_PREMIUM_ARGS+=(--dart-define=STRIPE_PREMIUM_MONTHLY_PRICE_ID="$STRIPE_PREMIUM_MONTHLY_PRICE_ID")
	STRIPE_PREMIUM_ARGS+=(--dart-define=STRIPE_PREMIUM_YEARLY_PRICE_ID="$STRIPE_PREMIUM_YEARLY_PRICE_ID")
	echo "💳 Price IDs premium web détectés: OK (redacted)"
else
	echo "⚠️ Price IDs premium web absents: le paywall web restera en configuration manquante."
fi
(cd app && flutter pub get && flutter build web --release --no-wasm-dry-run --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN" "${STRIPE_PREMIUM_ARGS[@]}")

FIREBASE_CMD="firebase"
if ! command -v firebase >/dev/null 2>&1; then
	echo "ℹ️ firebase CLI non trouvé, fallback via npx firebase-tools"
	if command -v npx >/dev/null 2>&1; then
		FIREBASE_CMD="npx --yes firebase-tools"
	else
		echo "❌ ERREUR: ni firebase CLI ni npx ne sont disponibles."
		exit 127
	fi
fi

$FIREBASE_CMD deploy --only hosting,functions,firestore:rules,firestore:indexes
echo "✅ Déployé"
echo ""

echo "════════════════════════════"
echo "✅ LIVRAISON TERMINÉE"
echo "════════════════════════════"
echo "✅ Commit + Push + Build + Deploy"