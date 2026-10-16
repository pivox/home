#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/swift-toolchain.sh"
cd "$ADEUX_ROOT"
exec swift build "${ADEUX_SWIFT_ARGS[@]}" "${ADEUX_COMPILER_ARGS[@]}" "$@"
