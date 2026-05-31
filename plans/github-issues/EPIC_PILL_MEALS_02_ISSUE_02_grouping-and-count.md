## Role

You are a senior SwiftUI engineer replacing the History skeleton's stubs with real per-meal grouping and a real compliance count.

## Goal

Each section header reads `"PILL BREAKFAST · fired 9:30 AM"` (uppercase section style with the meal name + target time). `ComplianceCount` returns the real per-day `(taken, scheduled)` so the footer reads `"All doses taken"` when equal, or `"N of M doses taken"` otherwise — never "missed" / "late".

## Context

- **Parent epic:** 187
- **Predecessor:** the History epic's skeleton issue.
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` §§ 7.2 (drill-down), 7.3 (compliance)
- **Files involved:**
  - `PillBreakfast/HistoryTab/DayDrillDownView.swift` — render real section headers.
  - `Shared/Queries/ComplianceCount.swift` — implement the real count.
  - `PillBreakfast/HistoryTab/ComplianceFooter.swift` — render the real footer copy.
  - `PillBreakfastTests/HistoryTab/ComplianceCountTests.swift` — replace skeleton assertions.
- **Prior decisions (locked):**
  - **No "late" / "missed" framing.** The footer is either `"All doses taken"` or `"N of M doses taken"`.
  - `scheduled` counts ScheduledDose entries that apply to the day (respecting `daysOfWeek`).
  - `taken` counts `DoseEvent` rows with `status == .taken` and `takenAt` inside the day.

## Output Format

A single PR containing:

- [ ] Section headers in `DayDrillDownView` render the real meal name + fired-at target time (uppercase via `Text.textCase(.uppercase)` or equivalent).
- [ ] `ComplianceCount.compliance(for:in:calendar:)` returns the real `(taken, scheduled)`.
- [ ] `ComplianceFooter` formats the result: `"All doses taken"` when equal and both > 0; `"N of M doses taken"` otherwise; `"No doses scheduled"` when `scheduled == 0`.
- [ ] Tests:
  - `taken == scheduled` → "All doses taken"
  - `taken < scheduled` → "N of M doses taken"
  - `scheduled == 0` → "No doses scheduled"
  - Ungrouped events show under "As-needed"
  - PRN ad-hoc events show under "As-needed" alongside any meal-routine PRN events

## Examples

```
PILL BREAKFAST · fired 9:30 AM
  9:42  · Lithium 300mg     · Taken
  9:43  · Vitamin D         · Taken

AS-NEEDED
  2:14 PM · Famotidine 20mg  · Taken

[ All doses taken ]
```

## Constraints

**Scope fence:** History drill-down only. **No** heatmap intensity changes. **No** PDF export changes.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Drill-down still navigates correctly. Heatmap unchanged. Existing day-drill-down tests still pass with the new section structure.

## Done-Done

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #187`.

## Labels

`spec-decomposition`, `core`, `phase-8-history-export`
