## Role

You are a senior SwiftUI engineer turning the iPhone History tab — heatmap, drill-down, share-sheet trigger — into the kind of view a user opens for reassurance, not just for an audit.

## Goal

Polish the History tab's visual hierarchy: heatmap that reads instantly, a drill-down that pages cleanly through a day's events, deliberate use of the design tokens (#158). The heatmap is currently functional but visually flat; it should be the brag-state for the app — the surface that says "you've been doing this consistently."

## Context

- **Parent epic:** #10 (Phase 9 — Hardening & TestFlight Submission).
- **Predecessor issue:** #158 (design token expansion).
- **SPEC sections:** §6.2 (history), §9 (visual design).
- **Files involved:**
  - `PillBreakfast/HistoryTab/HistoryTabView.swift` — navigation bar treatment, empty state polish, filter menu treatment.
  - `PillBreakfast/HistoryTab/HeatmapView.swift` — cell visual hierarchy, weekday/month axis labels (if missing), intensity legend.
  - `PillBreakfast/HistoryTab/DayDrillDownView.swift` — event row visual rhythm, day header treatment, ingredient summary card.

## Output Format

A single PR containing:

- [ ] **Heatmap cells**: tighten the grid rhythm with `Spacing.compact` interior padding, `CornerRadius.tight` cell corners, monochromatic intensity using opacity steps (no new colors). Add weekday letter labels along the left rail (`captionFont`/`footnoteFont`, `.secondary`) and month-change markers in the top rail.
- [ ] **Intensity legend** in the toolbar overflow or as a static caption beneath the grid — three or four labelled steps from "no doses" to "complete".
- [ ] **Empty state** ("No history yet") uses `displayFont` for the headline, custom SF Symbol hero, `footnoteFont` body — feels intentional.
- [ ] **Day drill-down**: day header in `displayFont` with weekday + date, events in `.elevation(.raised)` cards, time + medication + status in a clear hierarchy. Ingredient summary card pinned at the top with `CornerRadius.card` treatment.
- [ ] **Filter menu**: `headlineFont` for the menu label, `CornerRadius.standard` chip shape if customisable.
- [ ] **No new colors** — heatmap intensity uses opacity on the existing primary text/foreground.

## Constraints

**Scope fence:** History tab only. **No** changes to PDF export styling (that's an export concern, not a screen concern). **No** changes to the underlying queries.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Heatmap still renders 30 days, drill-down still navigates, share-sheet still produces the PDF.

## Definition of Done (stay-green)

- [ ] All existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; History reads as a refined surface.
- [ ] PR opened with `Refs #10` and `Closes #<this issue>`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
