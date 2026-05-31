## Role

You are a senior SwiftUI engineer skeletonizing the History tab's per-meal grouping. **Skeleton only** — the list re-organises into named sections keyed on `pillMeal?.id` and a compliance footer placeholder appears, but the section header copy and the count math are stubs returning typed mock values.

## Goal

`DayDrillDownView`'s events list is split into named sections: one per distinct meal touched by the day's events, plus a final "As-needed" section for events with `pillMeal == nil`. A `ComplianceFooter` view renders below the list with a stub `"0 of 0 doses taken"` placeholder, wired to a `ComplianceCount` helper that returns mock zeros.

## Context

- **Parent epic:** 187
- **Predecessor:** the Foundation epic's first issue (model + relationship) must be in `main`.
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` § 7 (history)
- **Files involved:**
  - `PillBreakfast/HistoryTab/DayDrillDownView.swift` — section the events list by `pillMeal?.id`.
  - `PillBreakfast/HistoryTab/ComplianceFooter.swift` (new) — placeholder footer.
  - `Shared/Queries/ComplianceCount.swift` (new) — stub helper.
  - `PillBreakfastTests/HistoryTab/ComplianceCountTests.swift` (new) — pin the helper signature only.

## Output Format

A single PR containing:

- [ ] `DayDrillDownView` renders one section per distinct meal id (or `nil`) found in the day's events. Section header copy is stub: `"Meal placeholder"`. Per-event row content unchanged.
- [ ] `ComplianceFooter` renders `"0 of 0 doses taken"` placeholder, wired to `ComplianceCount.compliance(for:in:calendar:) -> ComplianceCount.Result` (stub returning zeros).
- [ ] Tests pin the section partitioning (events with the same `pillMeal?.id` land in the same section) and the helper signature. **Do not** assert real count values yet.

## Examples

```swift
public enum ComplianceCount {
  public struct Result: Sendable { public let taken: Int; public let scheduled: Int }
  public static func compliance(
    for day: Date,
    in context: ModelContext,
    calendar: Calendar = .current
  ) -> Result {
    Result(taken: 0, scheduled: 0)  // skeleton stub
  }
}
```

## Constraints

**Scope fence:** Skeleton only. **No** real meal header copy. **No** real count math. **No** PDF / heatmap changes.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Drill-down still navigates, still shows all events, still pins the existing tests. Heatmap and PDF export unchanged.

## Done-Done

- [ ] All new and existing tests pass on both iOS and watchOS schemes.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #187`.

## Labels

`spec-decomposition`, `tracer-code`, `phase-8-history-export`
