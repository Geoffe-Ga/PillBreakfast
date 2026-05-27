## Role

You are a senior Swift engineer implementing the `AppIntent` that powers single-tap dose logging from the Smart Stack widget. You understand intent perform isolation and how to share writes with the main app via SwiftData + App Group.

## Goal

Implement `LogNextDoseIntent: AppIntent` that logs the next pending dose when invoked from the Smart Stack widget. **High-risk dose:** the widget surface for high-risk meds opens the app to the press-and-hold screen instead of logging directly. After a successful log, reload all complication timelines.

## Context

- **Parent epic:** #8
- **Predecessor issue(s):** #EPIC_08_ISSUE_03_NUMBER.
- **SPEC section:** `plans/SPEC.md` §7.5 ("Single-tap from widget → logs the next pending dose (no need to open app)"), §11 Phase 7 skill callout (`AppIntent`).
- **Files involved (new):**
  - `Shared/Intents/LogNextDoseIntent.swift`.
  - `WatchAppWidgets/SmartStackWidget.swift` — branch on the next pending dose's `isHighRisk`: render a `Button(intent:)` for non-high-risk, a deep-link `widgetURL` to the press-and-hold screen otherwise.
- **Prior decisions (locked):**
  - **High-risk meds never get a one-tap widget surface.** The widget renders "Open to confirm" for them. This preserves EPIC 04's safety guarantee.
  - The intent calls `DoseEventWriter.writeDoseEvent(...)` via the App Group's SwiftData container.
  - After a successful log, `WidgetCenter.shared.reloadAllTimelines()` is called.
- **State of the world:** Smart Stack widget exists but tapping opens the app.

## Output Format

A single PR containing:

- [ ] `LogNextDoseIntent` with `perform()` that writes the next non-high-risk pending dose.
- [ ] `SmartStackWidget` branches on `isHighRisk`.
- [ ] Tests: intent returns success for a fixture pending dose; intent returns failure (gracefully) for a high-risk dose; reload-timelines fires.
- [ ] Manual checklist: add a non-high-risk maintenance med; wait for the Smart Stack widget to surface; tap to log; observe the dose is recorded without opening the app.

## Constraints

**Scope fence:** No iOS-side widget. No background refresh — EPIC_08_ISSUE_05.

**One-tap log on high-risk is forbidden.** The intent must refuse and the widget must show the "Open to confirm" affordance instead.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Single-tap log works for non-high-risk; high-risk path stays safe.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #8` and `Closes #EPIC_08_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`.
