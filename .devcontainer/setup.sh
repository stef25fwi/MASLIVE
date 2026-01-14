#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y git curl unzip xz-utils zip libglu1-mesa

# Flutter (stable)
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi

echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter config --enable-web
flutter doctor
