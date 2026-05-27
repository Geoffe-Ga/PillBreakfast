## Role

You are a senior watchOS engineer wiring the snooze surface skeleton. You understand `UNNotificationAction`, `UNNotificationCategory`, and the foreground-vs-background trade-off.

## Goal

Register a custom `SNOOZE_UNTIL_TIME` `UNNotificationAction` with `.foreground` option on the `MAINTENANCE_DOSE` category. Add a stub `SnoozeView` that opens when the action fires, displays "Snooze stub — picker coming next issue," and dismisses on tap. No reschedule logic — that's EPIC_06_ISSUE_02.

## Context

- **Parent epic:** #6
- **Predecessor issue(s):** #EPIC_05_ISSUE_06_NUMBER (full EPIC 05 must be merged).
- **SPEC section:** `plans/SPEC.md` §2.2 (Snooze journey), §8.3 (Snooze-Until-Time flow).
- **Files involved:**
  - `Shared/Notifications/NotificationCategory.swift` — add the new action.
  - `WatchApp Watch App/SnoozeView/SnoozeView.swift` (new) — stub.
  - `WatchApp Watch App/Bootstrap/NotificationActionRouter.swift` (new) — handles the action ID and opens `SnoozeView`.
- **Prior decisions (locked):**
  - `.foreground` option so the app opens on tap (per SPEC §8.3 "dedicated `SnoozeView` on the watch").
  - Action ID: `"com.creekmasons.pillbreakfast.action.snoozeUntilTime"`.
- **State of the world:** EPIC 05 complete. Maintenance notifications fire but only offer Open / Mark-all-taken stub.

## Output Format

A single PR containing:

- [ ] New action registered on the `MAINTENANCE_DOSE` category.
- [ ] `NotificationActionRouter` listening for the action ID and surfacing `SnoozeView`.
- [ ] `SnoozeView` stub.
- [ ] Test that the category registration includes the snooze action.

## Examples

```swift
public enum NotificationActions {
    public static let snoozeUntilTime = "com.creekmasons.pillbreakfast.action.snoozeUntilTime"
}

let snoozeAction = UNNotificationAction(
    identifier: NotificationActions.snoozeUntilTime,
    title: "Snooze until…",
    options: [.foreground]
)
let category = UNNotificationCategory(
    identifier: "MAINTENANCE_DOSE",
    actions: [openAppAction, markAllTakenStubAction, snoozeAction],
    intentIdentifiers: []
)
```

## Constraints

**Scope fence:** No reschedule logic — EPIC_06_ISSUE_02. No `DatePicker` — EPIC_06_ISSUE_03. No `snoozeCount` field — EPIC_06_ISSUE_04.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Tapping Snooze on a notification opens the stub `SnoozeView`; everything else unchanged.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #6` and `Closes #EPIC_06_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-5-snooze`, `notifications`.
