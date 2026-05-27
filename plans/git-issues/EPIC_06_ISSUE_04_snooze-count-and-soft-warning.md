## Role

You are a senior Swift engineer adding the fourth-consecutive-snooze soft warning. You understand SwiftData lightweight migrations and "scheduled occurrence" identity (since a `DoseEvent` only exists for taken/skipped doses, not for snoozes).

## Goal

Track the snooze count per `(scheduledDoseID, calendarDay)` pair. On the fourth consecutive snooze, surface a soft "You've snoozed this 3 times — skip instead?" interstitial offering Snooze again / Skip / Take now. Persist the count so it survives app restarts. Schema migration must be **additive** (lightweight SwiftData migration).

## Context

- **Parent epic:** #6
- **Predecessor issue(s):** #EPIC_06_ISSUE_03_NUMBER.
- **SPEC section:** `plans/SPEC.md` §8.3 line 372 ("Edge case: If a snoozed notification is re-snoozed three times, surface a soft 'You've snoozed this 3 times — skip instead?' prompt on the fourth.").
- **Files involved:**
  - `Shared/Models/SnoozeRecord.swift` (new) — a small `@Model` keyed on `(scheduledDoseID, calendarDay)` with `count: Int` and `lastSnoozedAt: Date`.
  - `Shared/Persistence/PersistenceController.swift` — add `SnoozeRecord` to the schema (additive migration).
  - `Shared/Notifications/SnoozeRescheduler.swift` — increment the record's count atomically with the reschedule.
  - `WatchApp Watch App/SnoozeView/SnoozeWarningView.swift` (new) — the fourth-snooze interstitial.
  - `WatchApp Watch App/SnoozeView/SnoozeView.swift` — branch to `SnoozeWarningView` when `count >= 3`.
- **Prior decisions (locked):**
  - **Why a separate `SnoozeRecord` model instead of incrementing on `DoseEvent`:** `DoseEvent` is only created when a dose is logged (`.taken` / `.skipped`). A snoozed dose has no `DoseEvent` yet. Using a separate record keyed on the scheduled-occurrence identity is the cleanest approach.
  - The count is per *scheduled occurrence*, not per medication. Snoozing today's 8 AM Lithium three times does not affect tomorrow's 8 AM Lithium.
  - The record is cleared when the user takes or skips the dose (logging a `DoseEvent` for the same occurrence resets the count, or simply leaves the stale record — it never matters again).
- **State of the world:** EPIC_06_ISSUE_03 merged; snooze works end-to-end but the soft warning is missing.

## Output Format

A single PR containing:

- [ ] `SnoozeRecord` `@Model` with a compound-ish key (separate `scheduledDoseID: UUID` and `calendarDay: Date` fields; use a `(uuid, startOfDay)` lookup in queries).
- [ ] Schema migration is additive (lightweight); existing data is preserved.
- [ ] `SnoozeRescheduler` increments the count when a snooze is scheduled.
- [ ] `SnoozeView` checks the count on appear; routes to `SnoozeWarningView` if `count >= 3`.
- [ ] `SnoozeWarningView` offers three actions: Snooze again (returns to picker), Skip (writes `DoseEvent(status: .skipped)`), Take now (opens the tap-through queue for this dose).
- [ ] Tests: count increments on each snooze; routing flips to warning at count 3; taking or skipping a dose nullifies further warnings for that occurrence.

## Examples

```swift
@Model
public final class SnoozeRecord {
    @Attribute(.unique) public var id: UUID
    public var scheduledDoseID: UUID
    public var calendarDay: Date  // startOfDay
    public var count: Int
    public var lastSnoozedAt: Date

    public init(scheduledDoseID: UUID, calendarDay: Date, count: Int = 0, lastSnoozedAt: Date = .now) {
        self.id = UUID()
        self.scheduledDoseID = scheduledDoseID
        self.calendarDay = calendarDay
        self.count = count
        self.lastSnoozedAt = lastSnoozedAt
    }
}
```

Test:

```swift
func testFourthSnoozeOpensWarningInsteadOfPicker() async throws {
    // Arrange: schedule a snooze, increment 3 times, route the 4th to warning.
    let record = SnoozeRecord(scheduledDoseID: UUID(), calendarDay: startOfDay, count: 3)
    XCTAssertEqual(SnoozeViewRouter.routeForCount(record.count), .warning)
    XCTAssertEqual(SnoozeViewRouter.routeForCount(2), .picker)
}
```

## Constraints

**Scope fence:** No iPhone settings entry — EPIC_06_ISSUE_05.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Snoozing three times then trying a fourth shows the warning; everything else unchanged.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #6` and `Closes #EPIC_06_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `edges`, `phase-5-snooze`.
