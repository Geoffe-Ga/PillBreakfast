## Role

You are a senior Swift / SwiftUI engineer wiring the surface area of the maintenance flow. You understand `@Observable`, SwiftData `@Query`, and the "skeleton with stubs" tracer-code pattern.

## Goal

Wire the iPhone Regimen tab and the watch root "Right Now" view as real SwiftUI surfaces — both reading from the local SwiftData store via `@Query` — but with stub UI: the iPhone shows a grouped list (Maintenance / PRN headers, no edit affordances yet), and the watch shows the pending-queue placeholder reading the current time but always rendering a stub `MarkTakenView` with a stub button. No notification scheduling, no `DoseEvent` writes, no reverse sync. This is the skeleton issue for EPIC 03.

## Context

- **Parent epic:** #3
- **Predecessor issue(s):** #EPIC_02_ISSUE_05_NUMBER (full EPIC 02 must be merged so the stub medication exists on both devices).
- **SPEC section:** `plans/SPEC.md` §6.1 (iPhone Regimen tab structure, list layout only), §7.1 (watch root "Right Now"), §7.2 (tap-through queue shape, single-tap path).
- **Files involved (new):**
  - `iOSApp/RegimenTab/RegimenListView.swift` — grouped `List` with two sections, fed by `@Query` over `Medication`.
  - `iOSApp/RegimenTab/RegimenTabHostView.swift` — the host that becomes the Regimen tab.
  - `iOSApp/Navigation/MainTabView.swift` — replaces the temporary `RootView` from EPIC 02 with a `TabView` (Regimen / History / Settings — History + Settings are stub tabs).
  - `WatchApp Watch App/RootView/RightNowView.swift` — root view picking between "pending queue" and "all caught up" branches.
  - `WatchApp Watch App/TapThroughQueue/MarkTakenView.swift` — single-screen placeholder showing the medication name and a stub "Mark Taken" button that does nothing yet.
  - `Shared/Queue/PendingQueueSelector.swift` (new) — pure function `func pendingDoses(at now: Date, in context: ModelContext) -> [PendingDose]` returning whatever `ScheduledDose`s are within +/- 60 min of `now` and not yet taken today. Tested in EPIC_03_ISSUE_06.
- **Prior decisions (locked):**
  - The iPhone Regimen tab list is read-only in this issue. Add/edit/archive lands in EPIC_03_ISSUE_02.
  - The watch button is a stub. Writing a `DoseEvent` lands in EPIC_03_ISSUE_03.
- **State of the world:** EPIC 02 has landed. Both devices have a "Stub Lithium 300mg" with an 8:00 AM `ScheduledDose`. Editing on iPhone propagates. Watch shows the medication's name.

## Output Format

A single PR containing:

- [ ] `MainTabView` on iPhone with Regimen / History / Settings tabs; only Regimen has content, the other two are `Text("Coming soon")` stubs.
- [ ] `RegimenListView` reading via `@Query` and grouping by `kind` (Maintenance / PRN).
- [ ] `RightNowView` on the watch with the time-based branch and a `MarkTakenView` placeholder for any pending dose.
- [ ] `PendingQueueSelector.pendingDoses(at:in:)` as a pure helper. Concrete logic: "ScheduledDose s.t. `(now - 60min) <= scheduledFor <= (now + 60min)` AND no `DoseEvent.takenAt` matches `scheduledFor` today AND `medication.isArchived == false`."
- [ ] One smoke test per platform asserting that with the stub regimen present, the views render and the selector returns the expected count.

## Examples

`PendingQueueSelector` shape:

```swift
public struct PendingDose: Sendable, Hashable {
    public let medicationID: UUID
    public let scheduledFor: Date
    public let quantity: Int
}

@MainActor
public enum PendingQueueSelector {
    public static func pendingDoses(at now: Date, in context: ModelContext) throws -> [PendingDose] {
        // Skeleton implementation: returns []. Real logic in EPIC_03_ISSUE_06.
        return []
    }
}
```

(The skeleton returns `[]`. The watch's `RightNowView` then renders "All caught up" until EPIC_03_ISSUE_06 fills in the helper.)

## Constraints

**Scope fence:** No add/edit/archive UI on iPhone. No `DoseEvent` writes. No notifications. No reverse sync. If you find yourself touching `UserNotifications` or `WCSession.transferFile`, stop — those are later issues.

**iPhone never gets logging UI.** No "Mark Taken" button anywhere on iPhone, including the History tab placeholder.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both targets must build and run; iPhone shows the Stub Lithium under "Maintenance"; watch shows either "All caught up" or the placeholder `MarkTakenView`, depending on the current simulator time relative to 8:00 AM.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #3` and `Closes #EPIC_03_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-2-maintenance`.
