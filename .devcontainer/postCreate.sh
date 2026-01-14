#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y git curl unzip xz-utils zip libglu1-mesa

# Flutter (stable)
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi

# PATH flutter
grep -q 'flutter/bin' ~/.bashrc || echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/flutter/bin:$PATH"

flutter config --enable-web
flutter doctor -v || true

# Node + Firebase CLI (si npm dispo)
if command -v npm >/dev/null 2>&1; then
  sudo npm i -g firebase-tools || true
fi

# FlutterFire CLI
if command -v dart >/dev/null 2>&1; then
  dart pub global activate flutterfire_cli || true
  grep -q '.pub-cache/bin' ~/.bashrc || echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.bashrc
fi
