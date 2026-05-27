## Role

You are a senior SwiftUI engineer adding the medication filter to the History tab.

## Goal

Add a filter control on the History tab that scopes the heatmap intensity and the drill-down list to a single medication (or "All medications"). Filter state is per-session (not persisted).

## Context

- **Parent epic:** #9
- **Predecessor issue(s):** #EPIC_09_ISSUE_02_NUMBER.
- **SPEC section:** `plans/SPEC.md` §6.2.
- **Files updated:** `iOSApp/HistoryTab/HistoryTabView.swift`, `HeatmapView.swift`, `DayDrillDownView.swift`, `Shared/Queries/HistoryQueries.swift`.
- **Prior decisions (locked):**
  - `Picker` or `Menu` in the toolbar drives the filter.
  - Archived medications appear in the filter so the user can see their history.
- **State of the world:** Heatmap + drill-down work for "all medications."

## Output Format

A single PR containing:

- [ ] Filter UI in the toolbar.
- [ ] `HistoryQueries.dailySummary(...)` accepting an optional `medicationID` filter.
- [ ] Tests that the filter scopes correctly.

## Constraints

**Scope fence:** No multi-select filter.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Filter scoping works.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #9` and `Closes #EPIC_09_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `edges`, `phase-8-history-export`.
