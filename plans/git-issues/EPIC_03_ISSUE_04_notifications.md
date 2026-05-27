## Role

You are a senior watchOS engineer setting up `UserNotifications` on the watch directly. You understand `UNCalendarNotificationTrigger`, the rebuild-vs-diff trade-off, and why CLAUDE.md's "full notification rebuild on regimen edit" rule exists.

## Goal

Schedule local notifications on the **watch** (not the iPhone) for each `ScheduledDose`. Title: `"Pills · N to take"`; body: first two medication names plus `"+M more"` if more than two. Custom actions: **Open app** (default), **Mark all taken** (stub — no-op for now, EPIC 05 wires it; close issue note explains), **Snooze...** (stub — wired in EPIC 06). On every regimen change, **cancel all pending PillBreakfast notifications and re-schedule from scratch**.

## Context

- **Parent epic:** #3
- **Predecessor issue(s):** #EPIC_03_ISSUE_03_NUMBER (so the tap-through queue exists for the user to land in after tapping the notification).
- **SPEC section:** `plans/SPEC.md` §8.1 (Scheduling), §8.2 (Content), §10 Phase 2 ("Local notification scheduling (basic — fixed time, no snooze yet)").
- **Files involved (new):**
  - `Shared/Notifications/NotificationScheduler.swift` — pure scheduling helpers; takes a `RegimenSnapshot` or live `ModelContext` and produces `UNNotificationRequest`s.
  - `Shared/Notifications/NotificationCategory.swift` — registers the `MAINTENANCE_DOSE` category with the three actions.
  - `WatchApp Watch App/Bootstrap/NotificationBootstrap.swift` — calls the scheduler at app launch and after the regimen-applied callback fires.
- **Files updated:** `WatchApp Watch App/RootView/RightNowView.swift` — on appearance, request notification authorization if not yet determined.
- **Prior decisions (locked):**
  - **Schedule on the watch directly** so notifications fire when the iPhone is off (SPEC §8.1).
  - **Full rebuild on regimen edit** — cancel all `UNNotificationRequest`s with identifiers in the PillBreakfast namespace (`com.creekmasons.pillbreakfast.dose.<doseID>`), then re-add. CLAUDE.md.
  - Notification identifiers are namespaced so we never cancel unrelated requests.
  - **Watch notification request flow:** ask for authorization on first launch *after* the user has seen the empty Regimen list at least once, to avoid asking for permission before there's anything to remind them about. Practical implementation: trigger the request the first time the watch receives a non-empty `RegimenSnapshot`.
- **State of the world:** EPIC_03_ISSUE_03 has landed. The watch can log doses, but there are no notifications to remind the user.

## Output Format

A single PR containing:

- [ ] `NotificationScheduler.rebuildAll(from: RegimenSnapshot)` (or live-context overload) that cancels every PillBreakfast-namespaced pending notification and schedules fresh `UNCalendarNotificationTrigger`s. Repeats per the `ScheduledDose.daysOfWeek` array; an empty array means daily.
- [ ] `NotificationCategory.register()` called at watch launch, registering `MAINTENANCE_DOSE` with the three actions.
- [ ] The watch app delegate's `userNotificationCenter(_:didReceive:withCompletionHandler:)` opens the tap-through queue when the default action fires; the stub Mark-all-taken and Snooze... actions are wired only to call `completionHandler()` (so they don't error) and write a log line.
- [ ] On the iPhone, after each save in `EditMedicationView` / archive / add, transmit the updated snapshot to the watch (already happening from EPIC 02). On the watch, after applying the snapshot, call `NotificationScheduler.rebuildAll(...)`.
- [ ] Unit tests for the scheduler: given a fixture regimen, the produced `[UNNotificationRequest]` matches expectations (count, trigger times, identifier namespacing).

## Examples

`NotificationScheduler.rebuildAll`:

```swift
public enum NotificationScheduler {
    public static let identifierPrefix = "com.creekmasons.pillbreakfast.dose."

    @MainActor
    public static func rebuildAll(from snapshot: RegimenSnapshot, center: UNUserNotificationCenter = .current()) async {
        // 1. Cancel all PillBreakfast-namespaced pending requests.
        let pending = await center.pendingNotificationRequests()
        let toCancel = pending.filter { $0.identifier.hasPrefix(identifierPrefix) }.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: toCancel)

        // 2. Build a fresh set of UNNotificationRequest from the snapshot.
        for medication in snapshot.medications where !medication.isArchived && medication.kind == .maintenance {
            for dose in medication.schedule {
                let identifier = "\(identifierPrefix)\(dose.id.uuidString)"
                let content = makeContent(for: medication, dose: dose, snapshot: snapshot)
                let trigger = makeTrigger(for: dose)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }
}
```

The `try? await center.add(...)` here is the **documented exception** to the anti-bypass rule: scheduling one notification's failure must not block scheduling the rest. The reason and review date go above the line.

Manual checklist:

1. iPhone: add "Vitamin D 2000mg" at the next 1-minute slot.
2. Wait. Watch fires a notification with title "Pills · 1 to take" and body "Vitamin D".
3. Tap the notification -> watch app opens to the tap-through queue.
4. iPhone: archive Vitamin D. The watch's pending notifications list shrinks (verifiable via a debug log of `pendingNotificationRequests`).

## Constraints

**Scope fence:** No real Snooze... behavior (EPIC 06). No "Mark all taken" implementation (EPIC 05 or later). No iOS-side notifications — these are watch-only. No background-refresh complication updates (EPIC 08).

**Schedule on the watch.** A PR that schedules on iPhone and relies on Apple's forwarding must be rejected. The reason is "notifications fire when the iPhone is off" — SPEC §4 and §8.1.

**Full rebuild on every regimen change.** Do not optimize this with a diff. CLAUDE.md.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

The `try? await center.add(request)` in the rebuild loop is the one expected exception in this issue; document it inline.

**Tracer-code invariant:** Both targets build and run; the manual checklist completes.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair; the manual checklist completes.
- [ ] PR opened with `Refs #3` and `Closes #EPIC_03_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-2-maintenance`, `notifications`.
