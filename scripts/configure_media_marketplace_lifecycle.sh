#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT_ID:-${GCLOUD_PROJECT:-}}"
BUCKET="${FIREBASE_STORAGE_BUCKET:-}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "FIREBASE_PROJECT_ID ou GCLOUD_PROJECT est requis." >&2
  exit 1
fi

if [[ -z "${BUCKET}" ]]; then
  BUCKET="${PROJECT_ID}.appspot.com"
fi

echo "Activation du TTL Firestore sur media_photos.purgeAt..."
gcloud firestore fields ttls update purgeAt \
  --collection-group=media_photos \
  --enable-ttl \
  --project="${PROJECT_ID}" \
  --quiet

echo "Application du cycle de vie Storage sur gs://${BUCKET}..."
gcloud storage buckets update "gs://${BUCKET}" \
  --lifecycle-file=ops/storage/media-marketplace-lifecycle.json \
  --project="${PROJECT_ID}"

echo "Configuration terminée."
echo "Les documents media_photos expirés seront supprimés par TTL; le trigger syncMediaPhotoOnDelete supprimera les quatre fichiers associés."
