## Role

You are a senior SwiftUI engineer wiring the iPhone History tab skeleton.

## Goal

Replace the History tab placeholder from EPIC_03_ISSUE_01 with a real `HistoryTabView` containing a stub 30-day heatmap (one cell per day rendered as a uniform-density rectangle) and a stub drill-down that prints "Selected: <date>". Reads `DoseEvent`s from the local SwiftData store via `@Query`.

## Context

- **Parent epic:** #9
- **Predecessor issue(s):** Full EPIC 03 (so iPhone has `DoseEvent`s), EPIC 05 (so PRN totals are meaningful), EPIC 04 (design system).
- **SPEC section:** `plans/SPEC.md` §6.2 (History tab).
- **Files involved (new):**
  - `iOSApp/HistoryTab/HistoryTabView.swift`.
  - `iOSApp/HistoryTab/HeatmapStubView.swift`.
  - `iOSApp/HistoryTab/DayDrillDownStubView.swift`.
- **Prior decisions (locked):**
  - 30-day window, ending today, in the user's local calendar.
  - Stub renders all cells the same shade for now.
- **State of the world:** History tab is a "Coming soon" placeholder.

## Output Format

A single PR containing:

- [ ] `HistoryTabView` with the heatmap stub and drill-down navigation.
- [ ] Smoke tests that the view renders with 0 `DoseEvent`s and with a few fixture events.

## Constraints

**Scope fence:** No real heatmap intensity — EPIC_09_ISSUE_02. No PDF — EPIC_09_ISSUE_04. No filter — EPIC_09_ISSUE_03.

**iPhone never gets logging UI.** No "log this dose retroactively" affordance anywhere on the History tab.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** History tab is no longer a placeholder.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #9` and `Closes #EPIC_09_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-8-history-export`.
