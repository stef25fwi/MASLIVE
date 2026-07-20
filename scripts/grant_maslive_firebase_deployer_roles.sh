#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-maslive}"
DEPLOYER_SERVICE_ACCOUNT="${DEPLOYER_SERVICE_ACCOUNT:-firebase-adminsdk-fbsvc@maslive.iam.gserviceaccount.com}"
RUNTIME_SERVICE_ACCOUNT="${RUNTIME_SERVICE_ACCOUNT:-maslive@appspot.gserviceaccount.com}"
MEMBER="serviceAccount:${DEPLOYER_SERVICE_ACCOUNT}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud est requis. Exécute ce script dans Google Cloud Shell." >&2
  exit 1
fi

ACTIVE_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)"
if [[ -z "${ACTIVE_ACCOUNT}" ]]; then
  echo "Aucun compte Google Cloud actif. Lance: gcloud auth login" >&2
  exit 1
fi

echo "Projet: ${PROJECT_ID}"
echo "Compte propriétaire actif: ${ACTIVE_ACCOUNT}"
echo "Compte de déploiement: ${DEPLOYER_SERVICE_ACCOUNT}"

gcloud config set project "${PROJECT_ID}" >/dev/null

# Permissions exactes manquantes observées dans les journaux Firebase CLI.
for role in \
  roles/firebasestorage.viewer \
  roles/firebaserules.admin \
  roles/datastore.indexAdmin
do
  echo "Attribution de ${role} à ${MEMBER}..."
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="${MEMBER}" \
    --role="${role}" \
    --condition=None \
    --quiet >/dev/null
done

# Autorise le déployeur à attacher le compte d'exécution App Engine aux Functions.
echo "Attribution de roles/iam.serviceAccountUser sur ${RUNTIME_SERVICE_ACCOUNT}..."
gcloud iam service-accounts add-iam-policy-binding \
  "${RUNTIME_SERVICE_ACCOUNT}" \
  --project="${PROJECT_ID}" \
  --member="${MEMBER}" \
  --role="roles/iam.serviceAccountUser" \
  --condition=None \
  --quiet >/dev/null

echo
printf 'Correctif IAM appliqué. La propagation peut prendre quelques minutes.\n'
printf 'Relance ensuite le workflow GitHub: Build & Deploy Flutter Web with Mapbox.\n'
