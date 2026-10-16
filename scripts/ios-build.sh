#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcodebuild -version >/dev/null 2>&1; then
    echo 'Xcode complet est requis. Installez Xcode puis sélectionnez-le avec xcode-select.' >&2
    exit 2
fi
exec xcodebuild -project ADeux.xcodeproj -scheme ADeux -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "${ADEUX_DERIVED_DATA:-.build/DerivedData}" CODE_SIGNING_ALLOWED=NO build "$@"
