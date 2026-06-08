## Role

You are a senior watchOS engineer replacing the stub `PendingDoseTimelineProvider` with the real one: it reads the live pending-dose count from the shared SwiftData store and builds a 24-hour timeline whose entries land at every window-transition boundary, so the complication's count is correct as windows open and close.

## Goal

`getTimeline` opens the read-only container (via `makeContext()` from the skeleton child), computes the pending count at "now" and at each window opening edge (T − windowMins) and closing edge (T + windowMins) over the next 24 hours, and returns a `Timeline` with `.atEnd` policy. `getSnapshot` uses a fast current-count path; `placeholder` stays nil. All paths fall back to a single `pendingCount: nil` entry on any error.

## Context

- **Parent epic:** #49
- **Predecessor:** `EPIC_49_ISSUE_01_shared-membership-and-entry` (Shared membership, `displayText`/`hasPending`, `makeContext()` exist; provider still returns nil).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-49_three-complication-families.md` §5.2 (provider + timeline strategy + `transitionDates`), §5.7 (concurrency), §7 (edge cases), §9 (budget).
- **Files involved:**
  - `WatchAppWidgets/PendingDoseTimelineProvider.swift` — replace the stub bodies; add `pendingCount(at:)`, `buildEntries(lookahead:)`, `transitionDates(in:from:to:)`, and the `Duration` helpers.
- **Prior decisions (locked):**
  - Pending count comes from `PendingQueueSelector().pendingDoses(at:in:).count` — the canonical source of truth. Never recompute it inline.
  - `PendingQueueSelector` is `@MainActor`; WidgetKit calls `getTimeline` on the main thread on watchOS. If the Swift 6 checker flags an isolation crossing, mark `getTimeline` `@MainActor` (valid WidgetKit usage) — do NOT add `@unchecked Sendable` or `nonisolated(unsafe)`.
  - `PendingQueueSelector.isoWeekday(fromCalendar:)` is `internal` and lives in another module. Inline the one-liner (`gregorian == 1 ? 7 : gregorian - 1`) in `transitionDates` rather than widening its access (spec §10 resolution, option b).
  - `transitionDates` is a pure calendar walk over non-archived `.maintenance` meds' `schedule`, honoring `daysOfWeek` and guarding DST `nil` from `date(bySettingHour:minute:second:of:)` with `continue`.
  - Errors (container open failure, `CalendarError.*`) → fall back to one `pendingCount: nil` entry; log via `os.Logger`. The extension must never `fatalError` on a missing App Group URL — guard and return a placeholder entry.

## Output Format

A single PR containing:

- [ ] `getTimeline` returns transition-boundary entries from the real store with `.atEnd` policy; falls back to a single nil-count entry on error.
- [ ] `getSnapshot` uses a fast `pendingCount(at: .now)` path (or nil fallback); `placeholder` returns nil.
- [ ] `pendingCount(at:)` — opens a context, runs `PendingQueueSelector`, returns the count.
- [ ] `buildEntries(lookahead:)` — evaluates the count at `[now] + transitionDates` sorted; returns `[PendingDoseEntry]`.
- [ ] `transitionDates(in:from:to:)` — pure calendar walk producing opening/closing edges for active maintenance doses, with the inlined ISO-weekday conversion and DST guard.
- [ ] Read-only guarantee: no `context.save()` anywhere in the provider.
- [ ] Tests (`WatchAppWidgetsTests`, in-memory store): two scheduled doses 6h apart → `buildEntries` returns multiple transition entries with correct counts per injected `now`; `transitionDates` for one med with one `ScheduledDose` returns two dates (open + close).

## Examples

```swift
private static func pendingCount(at date: Date) throws -> Int {
    let context = try makeContext()
    return try PendingQueueSelector().pendingDoses(at: date, in: context).count
}
```

## Constraints

**Scope fence:** Provider data path only. **No** new family views or router (edges child #03), **no** URL-scheme/`onOpenURL` wiring (#03), **no** Smart Stack (#50). The complication still registers only `.accessoryCircular` after this PR — it now shows the live count instead of `"--"`.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The circular complication renders the real pending count (a numeral, `"✓"` when clear, `"--"` only in placeholder) on the paired simulator. Logging or scheduling a dose changes the count at the next timeline rebuild. The extension never writes to the store.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #49`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`, `watch`, `concurrency`
