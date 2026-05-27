## Role

You are a senior watchOS engineer implementing the Smart Stack widget that surfaces 15 minutes before each scheduled dose.

## Goal

Add a Smart Stack widget on the watch that surfaces 15 minutes before each `ScheduledDose` and shows the next medication's name + dose. Liquid Glass background.

## Context

- **Parent epic:** #8
- **Predecessor issue(s):** #EPIC_08_ISSUE_02_NUMBER.
- **SPEC section:** `plans/SPEC.md` §7.5 (Smart Stack widget, lines 340-343).
- **Files involved:**
  - `WatchAppWidgets/SmartStackWidget.swift` (new) — the widget.
  - `WatchAppWidgets/SmartStackTimelineProvider.swift` (new) — produces timeline entries 15 min before each scheduled dose.
- **Prior decisions (locked):**
  - The widget surfaces 15 minutes before. Apple controls actual surfacing; we provide the timeline with high relevance scores at those moments via `TimelineEntry.relevance`.
  - Tapping anywhere on the widget (other than a future tappable affordance from EPIC_08_ISSUE_04) opens the app.
- **State of the world:** Complications work.

## Output Format

A single PR containing:

- [ ] `SmartStackWidget` registered in the bundle.
- [ ] Timeline provider that emits entries 15 minutes before each scheduled dose with a high `TimelineEntryRelevance` score.
- [ ] Liquid Glass background, typography tokens.
- [ ] Snapshot test against a fixture timeline.

## Constraints

**Scope fence:** No `AppIntent`-driven single-tap log — EPIC_08_ISSUE_04. The widget in this issue opens the app on tap.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Smart Stack surface exists; tapping opens the tap-through queue.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #8` and `Closes #EPIC_08_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`.
