#!/usr/bin/env bash
# Vercel's build image has no Flutter: download the pinned SDK into ./flutter
# (cached between builds), then fetch packages.
set -euo pipefail
FLUTTER_VERSION="3.50.0"
if [ ! -x flutter/bin/flutter ] || ! grep -q "$FLUTTER_VERSION" flutter/version 2>/dev/null; then
  rm -rf flutter
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o flutter.tar.xz
  tar xf flutter.tar.xz
  rm flutter.tar.xz
fi
git config --global --add safe.directory "$PWD/flutter" || true
flutter/bin/flutter config --no-analytics >/dev/null
flutter/bin/flutter --version
flutter/bin/flutter pub get
