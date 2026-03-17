#!/bin/bash
# Setup Firestore promo codes configuration
# Run: bash setup_promo_codes.sh

set -e

PROJECT_ID=\"maslive\"

echo \"📋 Setting up Firestore promo codes config...\"
echo \"\"
echo \"Using Project: $PROJECT_ID\"
echo \"\"

# Check if firestore CLI is available
if ! command -v firebase &> /dev/null; then
    echo \"❌ Firebase CLI not found. Install: npm install -g firebase-tools\"
    exit 1
fi

# Create promo_codes config document via firestore-cli
cat > /tmp/promo_codes_config.json << 'EOF'
{
  \"codes\": {
    \"MAS10\": {
      \"type\": \"percentage\",
      \"value\": 10,
      \"maxDiscountCents\": null,
      \"minSubtotalCents\": 5000,
      \"expiresAt\": \"2026-12-31T23:59:59Z\",
      \"disabled\": false,
      \"description\": \"10% off all items\"
    },
    \"MEDIA5\": {
      \"type\": \"fixed\",
      \"value\": 500,
      \"minSubtotalCents\": 2000,
      \"expiresAt\": \"2026-12-31T23:59:59Z\",
      \"disabled\": false,
      \"description\": \"€5 fixed discount on media\"
    },
    \"WELCOME20\": {
      \"type\": \"percentage\",
      \"value\": 20,
      \"maxDiscountCents\": 2000,
      \"minSubtotalCents\": null,
      \"expiresAt\": \"2026-06-30T23:59:59Z\",
      \"disabled\": false,
      \"description\": \"20% off for new users (capped at €20)\"
    }
  }
}
EOF

echo \"📝 Promo codes config prepared.\"
echo \"\"
echo \"ℹ️  Manual setup via Firebase Console:\"
echo \"   1. Go to: https://console.firebase.google.com/project/$PROJECT_ID/firestore\"
echo \"   2. Create collection: 'config'\"
echo \"   3. Create document: 'promo_codes'\"
echo \"   4. Paste the following JSON:\"
echo \"\"

cat /tmp/promo_codes_config.json | jq '.'

echo \"\"
echo \"or use Firestore CLI to auto-create:\"
echo \"   firebase firestore:delete config/promo_codes --project=$PROJECT_ID\"
echo \"   firebase firestore:documents:set config/promo_codes <(cat /tmp/promo_codes_config.json) --project=$PROJECT_ID\"
echo \"\"
echo \"✅ Setup complete!\"
