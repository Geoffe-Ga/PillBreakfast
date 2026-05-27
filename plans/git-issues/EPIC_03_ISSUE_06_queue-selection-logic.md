## Role

You are a senior Swift engineer hardening the pure logic that decides what shows up in the watch's tap-through queue. You care about timezone correctness, "already taken today" detection, and writing the unit tests no one else will think to write.

## Goal

Replace the stub `PendingQueueSelector.pendingDoses(at:in:)` from EPIC_03_ISSUE_01 with a correct, fully-tested implementation that returns the right `[PendingDose]` for the watch's current moment. Cover the edge cases: timezone shifts, day-of-week filters (`ScheduledDose.daysOfWeek`), "already taken today" suppression keyed on `(scheduledDoseID, calendarDay)`, archived medications, the 60-minute window.

## Context

- **Parent epic:** #3
- **Predecessor issue(s):** #EPIC_03_ISSUE_05_NUMBER (reverse sync so the iPhone has the events too — same logic is reusable on iPhone in EPIC 09's History view).
- **SPEC section:** `plans/SPEC.md` §7.1 (Root View — "Right Now"). "Pending scheduled doses (within +/- 60 min of a scheduled time, not yet taken)."
- **Files updated:** `Shared/Queue/PendingQueueSelector.swift` — implement for real.
- **Files new:** `PillBreakfastTests/Queue/PendingQueueSelectorTests.swift` — comprehensive coverage.
- **Prior decisions (locked):**
  - The selector is **deterministic** given `now` and the SwiftData state. No `Date.now` reads inside; the caller passes `now`. This makes it testable.
  - "Already taken today" is determined by querying `DoseEvent` for the same `medication` and a `takenAt` (or `scheduledFor`) falling on the same `Calendar.current.startOfDay(for:)` as the dose's scheduled time today. Use `Calendar.current` (with the user's timezone) since this is a watch-local feature.
  - `ScheduledDose.daysOfWeek == []` means "every day."
  - Archived medications never appear in the queue regardless of schedule.
  - PRN medications (`kind == .prn`) never appear in the maintenance pending queue. PRN has its own section (EPIC 05).
- **State of the world:** EPIC_03_ISSUE_05 has landed. The stub selector returns `[]`. The pending-queue view shows "All caught up" most of the time.

## Output Format

A single PR containing:

- [ ] Real `PendingQueueSelector.pendingDoses(at:in:)` implementation.
- [ ] Tests covering:
  - **Happy path:** one `ScheduledDose` at 8:00 AM, `now = 8:05 AM`, queue contains one entry.
  - **Outside window:** same dose, `now = 7:00 AM` (61 min early) -> empty queue; `now = 9:05 AM` (65 min late) -> empty.
  - **Already taken:** a `DoseEvent` for that dose exists with `takenAt` today -> empty queue.
  - **Day-of-week mismatch:** dose `daysOfWeek = [1, 2, 3, 4, 5]` (weekdays), `now` is Saturday -> empty.
  - **Empty `daysOfWeek`:** treated as "every day" -> matches on Saturday.
  - **Archived medication:** medication `isArchived == true` -> empty.
  - **PRN medication:** `kind == .prn` -> empty.
  - **Multiple doses ordering:** two doses at 8:00 AM and 8:30 AM, `now = 8:15 AM`, queue contains both, sorted by scheduled time.
  - **Timezone:** dose at 8:00 AM local time, simulator in Pacific, change calendar to Eastern via injected `Calendar` -> selector still returns relative to the caller's calendar.
- [ ] `RightNowView` on the watch now reflects real data; the watch UI flicks correctly between "pending queue" and "all caught up."

## Examples

`PendingQueueSelector` (with injected `Calendar` and `Date`):

```swift
public struct PendingQueueSelector: Sendable {
    public let windowMinutes: Int
    public let calendar: Calendar

    public init(windowMinutes: Int = 60, calendar: Calendar = .current) {
        self.windowMinutes = windowMinutes
        self.calendar = calendar
    }

    @MainActor
    public func pendingDoses(at now: Date, in context: ModelContext) throws -> [PendingDose] {
        let weekday = calendar.component(.weekday, from: now)
        let startOfDay = calendar.startOfDay(for: now)
        let descriptor = FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived && $0.kind == .maintenance })
        let meds = try context.fetch(descriptor)

        var results: [PendingDose] = []
        for med in meds {
            for dose in med.schedule {
                let scheduledToday = scheduledTime(for: dose, on: startOfDay)
                let delta = abs(scheduledToday.timeIntervalSince(now)) / 60
                guard delta <= Double(windowMinutes) else { continue }
                guard dose.daysOfWeek.isEmpty || dose.daysOfWeek.contains(weekday) else { continue }

                let alreadyTaken = med.doseEvents.contains { event in
                    guard let scheduledFor = event.scheduledFor else { return false }
                    return calendar.isDate(scheduledFor, inSameDayAs: scheduledToday)
                }
                guard !alreadyTaken else { continue }

                results.append(PendingDose(
                    medicationID: med.id,
                    scheduledFor: scheduledToday,
                    quantity: dose.quantity
                ))
            }
        }
        return results.sorted { $0.scheduledFor < $1.scheduledFor }
    }

    private func scheduledTime(for dose: ScheduledDose, on day: Date) -> Date {
        calendar.date(bySettingHour: dose.hour, minute: dose.minute, second: 0, of: day) ?? day
    }
}
```

## Constraints

**Scope fence:** Don't touch the tap-through queue UI; it already consumes whatever the selector returns. Don't touch the iPhone Regimen tab. Don't touch notification scheduling.

**Determinism is the testing contract.** No `Date.now` inside the selector. No `Calendar.current` inside the selector (use the injected one). The tests must be fully deterministic.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Watch tap-through queue now shows real data; the rest of the system is unchanged.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #3` and `Closes #EPIC_03_ISSUE_06_NUMBER`.

## Labels

`spec-decomposition`, `edges`, `phase-2-maintenance`.
