## Role

You are a senior SwiftUI engineer building the 30-day heatmap and per-day drill-down.

## Goal

Render the 30-day calendar heatmap with intensity computed from `DoseEvent` counts per day (monochromatic shades; no rainbow). Tapping a day opens `DayDrillDownView` listing every `DoseEvent` chronologically with timestamp, medication, quantity, status icon, and per-day PRN ingredient running totals.

## Context

- **Parent epic:** #9
- **Predecessor issue(s):** #EPIC_09_ISSUE_01_NUMBER.
- **SPEC section:** `plans/SPEC.md` §6.2.
- **Files involved:**
  - `iOSApp/HistoryTab/HeatmapView.swift` — replace stub.
  - `iOSApp/HistoryTab/DayDrillDownView.swift` — replace stub.
  - `Shared/Queries/HistoryQueries.swift` (new) — pure helpers for daily summaries.
- **Prior decisions (locked):**
  - **Monochromatic intensity.** No color leak; the heatmap is a single hue with varying opacity. CLAUDE.md.
  - PRN ingredient totals on the drill-down read from denormalized `DoseEvent.ingredientAmounts`.
- **State of the world:** Stub heatmap and drill-down exist.

## Output Format

A single PR containing:

- [ ] `HistoryQueries.dailySummary(in: ModelContext, day: Date) -> DailySummary` returning a struct with: dose counts by status, PRN ingredient totals.
- [ ] `HeatmapView` rendering 30 cells with opacity proportional to total dose count.
- [ ] `DayDrillDownView` listing events with status icons.
- [ ] Tests on `HistoryQueries.dailySummary` covering single-product day, multi-product day, mixed-status day.

## Constraints

**Scope fence:** No filter — EPIC_09_ISSUE_03. No PDF — EPIC_09_ISSUE_04.

**Color discipline.** Heatmap is one hue with opacity. Status icons can use SF Symbols glyphs but not custom-colored chrome. No amber anywhere (that's reserved for high-risk live confirms).

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Heatmap + drill-down work.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #9` and `Closes #EPIC_09_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-8-history-export`.
