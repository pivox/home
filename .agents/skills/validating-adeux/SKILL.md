---
name: validating-adeux
description: Use when verifying À deux changes, diagnosing local Swift toolchain test failures, preparing delivery, or reporting iOS and CloudKit readiness.
---

# Validating À deux

Read the Makefile, `scripts/swift-toolchain.sh` and the relevant tests. The package uses Swift Testing, tools 6.0 and Swift 5 language mode. Distinguish a failing app assertion from an unavailable framework, stale PackageDescription interface, missing macro plugin or runtime library.

| Command | Evidence it can provide |
| --- | --- |
| `make test` | Domain, local persistence and reminder assertions on this Mac |
| `make build` | Shared SwiftUI module compilation for macOS |
| `make validate` | Repository, project and source checks implemented by the validator |
| `make project` | Regeneration of the Xcode project |
| `make ios-build` | iOS Simulator compilation when full Xcode and its SDK are available |
| `make preview` | Repository preview artifact; inspect its implementation before treating it as native UI evidence |

Use repository wrappers for normal verification. Their standalone Command Line Tools compatibility adjustments live in a temporary cache; do not copy a successful machine’s absolute paths into source or global configuration. Inspect the actual failure before changing requirements or silencing diagnostics. Focused tests can be run through `scripts/swift-test.sh --filter DeuxCoreTests` or the corresponding persistence/reminder suite.

A passing macOS build does not compile the iOS app target. Syntax/project checks do not establish signing, entitlements, notifications, accessibility or CloudKit convergence. Follow `docs/apple-setup.md` for two-account sharing and offline/relaunch checks on Apple devices.

Report the exact command, outcome and meaningful counts, then state unperformed checks explicitly. Treat missing Xcode, SDK, account or entitlement configuration as unverified capability. Delivery can include that honest status; do not turn local save success into “iCloud tested.”
