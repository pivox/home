# À deux — agent guide

Native French household app for two people. Read `README.md` for setup and `docs/architecture.md` before changing module boundaries. iOS 17 / macOS 14; Swift Package tools 6.0, Swift 5 language mode; Xcode 16 or newer for the normal Apple workflow. Tests use Swift Testing.

## Code map

| Location | Responsibility |
| --- | --- |
| `Sources/DeuxCore/` | Codable value snapshots, task rules, calendar arithmetic and completion-based insights; Foundation only |
| `Sources/DeuxPersistence/` | `@MainActor HouseholdStore`, Core Data graph, private/shared CloudKit stores and sharing operations |
| `Sources/DeuxUI/` | SwiftUI screens; `DeuxRootView` coordinates task actions, `DesignSystem.swift` owns shared visual patterns |
| `Sources/DeuxNotifications/` | Pure reminder planning and platform notification scheduling |
| `App/` | iOS lifecycle, native sharing controller, invitation delegates and permission-on-demand integration |
| `Tests/` | Domain, persistence and reminder tests |
| `scripts/`, `Makefile` | Project generation and repeatable validation |

## Invariants

- Keep `personOne` / `personTwo` stable. Names are editable labels. `currentPerson` belongs to this device; it is not the household’s shared owner. `.anyone` is an assignment choice, not a valid completion identity.
- Views call store methods and show their errors. Do not mutate published snapshots as a substitute for persistence. New tasks and completion records belong to the active household’s persistent store and inverse relationship.
- `TaskRules.complete` creates an immutable historical snapshot and advances recurring due dates beyond today using the injected calendar. Insights sum completion snapshots once. Undo must preserve the latest-occurrence guard; deleting a task retains its history.
- Local mode works without Apple configuration. A local save, accepted invitation or enabled capability does not prove synchronization. Preserve visible error/retry states and describe only observed CloudKit operations.
- Preserve French copy, shared cream/sage/apricot tokens, accessible control names and selection states. Respect reduced motion and large text. Gate iOS-only modifiers so shared UI still compiles for macOS.
- Do not insert starter routines or ask for notification permission automatically. Both require explicit user actions in the app.

## Work and evidence

Run `make test`, `make build` and `make validate` for tests, shared UI compilation and repository checks. Regenerate the Xcode project with `make project` after changing its generator or app source list. `make ios-build` needs full Xcode; `make preview` produces a development artifact whose capabilities are described by its script. Report tests, shared-module compilation, iOS build, visual checks and two-account CloudKit checks separately. Missing Xcode or Apple credentials is a capability limit, not a passing check. Keep portable instructions free of local machine paths or temporary toolchain fixes.

Use `.agents/skills/developing-swiftui`, `.agents/skills/cloudkit-sharing` or `.agents/skills/validating-adeux` when the matching task needs their repository-specific guidance. The same skills are exposed to Claude through `.claude/skills`.
