## Role

You are a senior Apple-platforms engineer wiring background refresh that keeps the complication and Smart Stack widget current.

## Goal

Call `WidgetCenter.shared.reloadAllTimelines()` after every `DoseEvent` write on both targets. Add a `WKApplicationRefreshBackgroundTask` (watchOS) handler that pre-computes the next pending-count timeline. Batch reloads when many writes happen in a short window.

## Context

- **Parent epic:** #8
- **Predecessor issue(s):** #EPIC_08_ISSUE_04_NUMBER.
- **SPEC section:** `plans/SPEC.md` §7.4 ("Shows count of pending doses for current window... Tap → opens app to tap-through queue."), §10 Phase 7 gate ("See pending count update in real time after a dose is logged").
- **Files involved (new):**
  - `Shared/Background/WidgetReloadCoordinator.swift` — pending-write debouncer that calls `WidgetCenter.shared.reloadAllTimelines()` at most once per 2 seconds.
  - `WatchApp Watch App/Bootstrap/BackgroundRefreshHandler.swift` — registers and handles `WKApplicationRefreshBackgroundTask`.
- **Prior decisions (locked):**
  - Debounce at 2 seconds — fast enough to feel real-time on the gate test, slow enough to not blow the complication budget.
  - The handler runs lightly: it just reloads timelines and schedules the next background refresh.
- **State of the world:** Widgets work but only update when the app is opened.

## Output Format

A single PR containing:

- [ ] `WidgetReloadCoordinator.scheduleReload()` invoked from `DoseEventWriter` and `DoseEventBatchMerger`.
- [ ] `BackgroundRefreshHandler` registered at watch launch.
- [ ] Tests: writing two `DoseEvent`s within 2 seconds triggers one reload, not two.
- [ ] Manual checklist: log a dose, observe the complication pending count decrement within 60 seconds.

## Constraints

**Scope fence:** No new widget surfaces.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** End of EPIC 08. Phase 7 gate passes.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; Phase 7 gate manual checklist completes.
- [ ] PR opened with `Refs #8` and `Closes #EPIC_08_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `edges`, `phase-7-widgets`.
