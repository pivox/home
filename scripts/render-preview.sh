#!/usr/bin/env bash
set -euo pipefail
ADEUX_PREVIEW_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ADEUX_PREVIEW_ROOT"
./scripts/swift-build.sh --product DeuxPreview
ADEUX_PREVIEW_BIN="$(./scripts/swift-build.sh --show-bin-path)"
exec "$ADEUX_PREVIEW_BIN/DeuxPreview" --output "$ADEUX_PREVIEW_ROOT/docs/images" "$@"
