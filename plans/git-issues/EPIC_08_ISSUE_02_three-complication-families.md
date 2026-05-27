## Role

You are a senior watchOS engineer expanding the complication to all three families and wiring it to real data.

## Goal

Implement `.accessoryCircular`, `.accessoryCorner`, and `.accessoryInline` complications all rendering the real pending count (from `PendingQueueSelector`) or `"✓"` when clear. Tapping any family opens the watch app to the tap-through queue via `widgetURL`.

## Context

- **Parent epic:** #8
- **Predecessor issue(s):** #EPIC_08_ISSUE_01_NUMBER.
- **SPEC section:** `plans/SPEC.md` §7.4 lines 334-337.
- **Files updated:** `WatchAppWidgets/PendingDoseTimelineProvider.swift`, `PendingDoseComplication.swift`.
- **Files new:** `WatchAppWidgets/Variants/CornerComplicationView.swift`, `InlineComplicationView.swift`, `CircularComplicationView.swift`.
- **Prior decisions (locked):**
  - Liquid Glass background.
  - Deep-link URL scheme: `pillbreakfast://tap-through`. Main app handles via `onOpenURL`.
- **State of the world:** One stub complication exists.

## Output Format

A single PR containing:

- [ ] Three complication variants registered in the `WidgetBundle`.
- [ ] Real `TimelineProvider` reading from SwiftData via the App Group.
- [ ] `widgetURL(URL("pillbreakfast://tap-through"))` on each variant.
- [ ] Watch main app handles the URL and routes to the tap-through queue.
- [ ] Snapshot tests for each family using known fixtures.

## Constraints

**Scope fence:** No Smart Stack widget — EPIC_08_ISSUE_03.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** All three complications render real data and deep-link correctly.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs; all three families render on a watch face.
- [ ] PR opened with `Refs #8` and `Closes #EPIC_08_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`.
