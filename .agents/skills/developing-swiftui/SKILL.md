---
name: developing-swiftui
description: Use when changing À deux SwiftUI screens, task editing, household profiles, filters, completion feedback, or accessibility across iOS and macOS.
---

# Developing À deux SwiftUI

Keep UI state temporary and persisted state in `HouseholdStore`. Read `AGENTS.md`, then the affected screen and `Sources/DeuxUI/DesignSystem.swift`; the shared palette, cards, pills and platform modifiers already exist.

| Change | Existing route |
| --- | --- |
| Add/edit task | `DeuxRootView` sheet → `TaskEditorView` draft → `saveTask` |
| Complete/undo | Root action or `HistoryView` → store mutation → domain rules |
| Household names | `ProfileEditorView` → `updateHousehold` |
| Filters | Person filters in `TodayView` and `PlanningView`; category/date filters in `PlanningView`; shared controls in `TaskComponents.swift` |

Keep `personOne` and `personTwo` identifiers when names change; display names come from `store.name(for:)`. Completion attribution uses the device’s `currentPerson`, regardless of task assignment. Display effort from persisted `TaskCompletion` snapshots through `TaskInsights`; a recurring task remains open after completion, so counting open task records cannot measure contributions.

Follow the editor’s draft-and-save pattern: validate, call the throwing store method, and dismiss only after success. Present errors through existing banners or alerts. Preserve empty, loading and retry states; starter routines remain an explicit action.

Write French labels consistent with Aujourd’hui, Planning and Maison. Give icon-only controls accessible names and selected filters explicit selection traits. Check long names, large text, empty filters and reduced motion; compilation alone proves none of these visually. Reuse iOS guards for keyboard, navigation and sheet modifiers so macOS builds remain useful. Native sharing and notification permission requests stay in the `DeuxRootView` callbacks, implemented by `App/AppServices.swift`.
