## Role

You are a senior Swift engineer writing the deterministic reschedule logic. Pure functions over `Date`, `Calendar`, and `UNCalendarNotificationTrigger`, with thorough unit tests including post-midnight rollover.

## Goal

Implement `SnoozeRescheduler` in `Shared/Notifications/`: given a `(scheduledDoseID, originalScheduledFor, snoozeUntilLocalTime, now)`, cancel the original pending re-fire by identifier and schedule a fresh `UNCalendarNotificationTrigger` for the chosen wall-clock time. If `snoozeUntilLocalTime` is earlier than `now`, schedule for tomorrow at that time. Comprehensive unit tests with `nonisolated(unsafe)` test doubles for the notification center.

## Context

- **Parent epic:** #6
- **Predecessor issue(s):** #EPIC_06_ISSUE_01_NUMBER.
- **SPEC section:** `plans/SPEC.md` §8.3 (Snooze-Until-Time flow steps 1-5, plus the edge case in line 372).
- **Files involved (new):**
  - `Shared/Notifications/SnoozeRescheduler.swift`.
  - `Shared/Notifications/UNUserNotificationCenterProtocol.swift` — protocol over the parts of `UNUserNotificationCenter` we use, to enable a fake in tests.
  - `PillBreakfastTests/Notifications/SnoozeReschedulerTests.swift`.
- **Prior decisions (locked):**
  - **One-shot, not repeating.** `UNCalendarNotificationTrigger(dateMatching: components, repeats: false)`.
  - Snooze identifier: `"com.creekmasons.pillbreakfast.snooze.<scheduledDoseID>.<isoDate>"` — namespaced so reschedules cancel only the relevant prior snooze, not the daily fire.
  - **Daily schedule unaffected.** The original `UNCalendarNotificationTrigger(dateMatching: hour+minute, repeats: true)` continues to fire on subsequent days.
- **State of the world:** EPIC_06_ISSUE_01 merged; action opens stub view.

## Output Format

A single PR containing:

- [ ] `SnoozeRescheduler.snooze(scheduledDoseID:originalScheduledFor:snoozeUntil:now:center:calendar:)` — fully tested.
- [ ] Protocol-wrapped notification center for testing.
- [ ] Tests: future-time-same-day; future-time-tomorrow (post-midnight rollover); idempotent re-snooze (re-call with new time cancels previous snooze + schedules new); rescheduling does not cancel the daily recurring fire.

## Examples

```swift
public protocol NotificationScheduling: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

public enum SnoozeRescheduler {
    public static let snoozeIdentifierPrefix = "com.creekmasons.pillbreakfast.snooze."

    public static func snooze(
        scheduledDoseID: UUID,
        originalScheduledFor: Date,
        snoozeUntil: DateComponents, // hour + minute only
        now: Date,
        center: any NotificationScheduling,
        calendar: Calendar = .current
    ) async throws {
        let target = resolveTarget(from: snoozeUntil, now: now, calendar: calendar)
        let identifier = "\(snoozeIdentifierPrefix)\(scheduledDoseID).\(ISO8601.string(from: originalScheduledFor))"

        // Cancel previous snooze for this scheduled occurrence.
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Snoozed pill ready"
        content.categoryIdentifier = "MAINTENANCE_DOSE"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target),
            repeats: false
        )
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func resolveTarget(from components: DateComponents, now: Date, calendar: Calendar) -> Date {
        let today = calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: now) ?? now
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
```

Key tests:

```swift
func testPostMidnightRollover() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let now = makeDate("2026-05-15 23:50:00", calendar: calendar)
    let target = SnoozeRescheduler.resolveTarget(
        from: DateComponents(hour: 6, minute: 30), now: now, calendar: calendar
    )
    XCTAssertEqual(target, makeDate("2026-05-16 06:30:00", calendar: calendar))
}
```

## Constraints

**Scope fence:** No UI — `SnoozeView` picker is EPIC_06_ISSUE_03. No `snoozeCount` field — EPIC_06_ISSUE_04. No iPhone settings entry — EPIC_06_ISSUE_05.

**One-shot triggers only.** A PR that schedules a `repeats: true` trigger for snooze must be rejected.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Pure logic in place; UI still shows stub. No regression.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #6` and `Closes #EPIC_06_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-5-snooze`, `notifications`.
