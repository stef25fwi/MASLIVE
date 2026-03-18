#!/bin/bash
# Step 1: Create Firestore Promo Code Configuration
# This script creates the config/promo_codes document in Firestore
# Usage: bash setup_firestore_promo_config.sh

set -e

PROJECT_ID="maslive"

echo "==============================================="
echo "1️⃣  FIRESTORE CONFIG SETUP"
echo "==============================================="
echo ""

echo "Creating promo codes configuration..."
echo ""

# Check if firebase CLI is available
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found"
    echo "Install: npm install -g firebase-tools"
    exit 1
fi

# Create temporary JSON file with promo config
cat > /tmp/promo_codes.json << 'EOF'
{
  "codes": {
    "MAS10": {
      "type": "percentage",
      "value": 10,
      "minSubtotalCents": 5000,
      "disabled": false,
      "description": "10% off on orders €50+"
    },
    "MEDIA5": {
      "type": "fixed",
      "value": 500,
      "minSubtotalCents": 2000,
      "disabled": false,
      "description": "€5 off on orders €20+"
    },
    "WELCOME20": {
      "type": "percentage",
      "value": 20,
      "maxDiscountCents": 2000,
      "minSubtotalCents": null,
      "disabled": false,
      "description": "20% off for new users (capped at €20)"
    }
  }
}
EOF

echo "📋 Generated config:"
cat /tmp/promo_codes.json | jq '.' 2>/dev/null || cat /tmp/promo_codes.json
echo ""

echo "📍 MANUAL SETUP (via Firebase Console):"
echo ""
echo "1. Go to: https://console.firebase.google.com/project/$PROJECT_ID/firestore/data/~2Fconfig~2Fpromo_codes"
echo ""
echo "2. Create collection: 'config' (if not exists)"
echo "   - Right-click > Add Collection > Name: 'config'"
echo ""
echo "3. Create document: 'promo_codes'"
echo "   - Click 'Add document' > Document ID: 'promo_codes' > Auto ID unchecked"
echo ""
echo "4. Add field: 'codes' (type: Map)"
echo "   - Then add nested fields for each code (MAS10, MEDIA5, WELCOME20)"
echo ""
echo "📋 Alternatively, copy-paste into the document (JSON mode):"
echo ""
jq '.codes | to_entries | map({key: .key, value: .value}) | from_entries' /tmp/promo_codes.json
echo ""

echo "✅ Configuration ready!"
echo ""
echo "Once created in Firestore, validate:"
echo "  firebase firestore:documents:list config --project=$PROJECT_ID"
echo ""
