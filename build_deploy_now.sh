#!/bin/bash
set -e

echo "📱 Building Flutter web app..."
cd /workspaces/MASLIVE/app
flutter build web --release --no-wasm-dry-run

echo "🚀 Deploying to Firebase hosting..."
cd /workspaces/MASLIVE
firebase deploy --only hosting

echo "✅ Build and deploy completed!"
