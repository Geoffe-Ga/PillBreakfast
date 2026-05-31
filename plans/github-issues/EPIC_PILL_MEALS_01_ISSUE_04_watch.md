## Role

You are a senior watchOS engineer adding meal context to the tap-through queue: a header line on each card and a brief per-meal success micro-state between meals.

## Goal

When the user is paging through a meal's doses, the `MarkTakenView` card shows a small header line: `"Pill Breakfast · 2 of 5"` in `captionFont` secondary above the medication name. After confirming the last dose in a meal, a 0.5-second micro-state reads "Pill Breakfast logged ✓" with the existing `Motion.dramatic` reveal, then advances to the next meal's first card (or `QueueSuccessView` if the queue is empty).

## Context

- **Parent epic:** 186
- **Predecessors:** model + relationship (skeleton), editor (assignment), notifications (meal-aware grouping).
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` §§ 5.2 (tap-through), 5.3 (mid-meal cancel)
- **Files involved:**
  - `Shared/Queue/PendingQueueSelector.swift` — surface meal grouping on each `PendingDose` (already has `scheduledFor`; add `mealName: String?` and `mealOrdinal: (current: Int, total: Int)?`).
  - `PillBreakfast Watch App Watch App/TapThroughQueue/TapThroughQueueView.swift` — use meal grouping to drive the header + micro-state.
  - `PillBreakfast Watch App Watch App/TapThroughQueue/MarkTakenView.swift` — render the meal header line.
  - `PillBreakfast Watch App Watch App/TapThroughQueue/MealCompletionView.swift` (new) — the micro-state ("Pill Breakfast logged ✓").

## Output Format

A single PR containing:

- [ ] `PendingDose` (or a sibling DTO) carries the meal name + 1-based ordinal-of-total within its meal.
- [ ] `MarkTakenView` renders the optional header (`Pill Breakfast · 2 of 5`) above the medication name.
- [ ] After the last dose in a meal confirms, the queue presents `MealCompletionView` for `~0.5s` (`Motion.dramatic`), then advances. The existing `QueueSuccessView` continues to handle the all-clear at the end of the whole pending set.
- [ ] Mid-meal queue dismissal: unlogged doses stay pending; re-opening resumes with the correct ordinal.
- [ ] Tests pin the ordinal helper (1/5 → 2/5 → 5/5) and the `MealCompletionView` auto-advance lifecycle.

## Examples

```
       Pill Breakfast · 2 of 5             ← captionFont secondary
       Lithium 300mg                       ← displayFont
       300mg · 1 tablet                    ← dosageFont
       [ Hold to confirm ]                 ← unchanged for high-risk
```

## Constraints

**Scope fence:** Watch tap-through only. **No** history grouping (separate epic). **No** widgets / complications.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Ungrouped doses keep the existing card with no meal header. Press-and-hold gestures on high-risk doses are unchanged. Reduce-motion suppresses the `Motion.dramatic` reveal on `MealCompletionView`.

## Done-Done

- [ ] All new and existing tests pass on both iOS and watchOS schemes.
- [ ] `pre-commit run --all-files` is clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Closes #<this issue>` and `Refs #186`.

## Labels

`spec-decomposition`, `core`, `phase-4-prn-safety`
