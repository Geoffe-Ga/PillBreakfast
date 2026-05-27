## Role

You are a senior watchOS engineer setting up the watch widget extension target. You understand `WidgetBundle`, `TimelineProvider`, and the relationship between widgets and complications on watchOS 26.

## Goal

Add a new watch widget extension target to the Xcode project. Implement a single complication family (`.accessoryCircular`) rendering a stub `"--"` pending count. The widget is configured to be available on the watch face but does not yet read real data.

## Context

- **Parent epic:** #8
- **Predecessor issue(s):** Full EPIC 03 (logging machinery) and EPIC 04 (design system).
- **SPEC section:** `plans/SPEC.md` §7.4 (complication), §10 Phase 7.
- **Files involved (new):**
  - `WatchAppWidgets/WatchAppWidgetsBundle.swift` — `@main` `WidgetBundle`.
  - `WatchAppWidgets/PendingDoseComplication.swift` — circular complication.
  - `WatchAppWidgets/PendingDoseTimelineProvider.swift` — stub provider returning a single entry with `"--"`.
- **Prior decisions (locked):**
  - The extension shares the App Group with the main targets so it can read `SwiftData` later.
  - One family per issue: only `.accessoryCircular` here; corner and inline are EPIC_08_ISSUE_02.
- **State of the world:** No widget extension exists.

## Output Format

A single PR containing:

- [ ] New `WatchAppWidgets` extension target with the App Group entitlement.
- [ ] One circular complication that renders "--" centered.
- [ ] Stub `TimelineProvider`.
- [ ] Updated build scripts / scheme list if needed.

## Constraints

**Scope fence:** No reading from SwiftData yet — EPIC_08_ISSUE_02 wires the real provider. No Smart Stack widget — EPIC_08_ISSUE_03. No `AppIntent` — EPIC_08_ISSUE_04.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Adding the complication to a watch face works and renders "--".

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs; complication renders on the watch face.
- [ ] PR opened with `Refs #8` and `Closes #EPIC_08_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-7-widgets`.
