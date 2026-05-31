## Role

You are a senior SwiftUI engineer building the iPhone meal CRUD: a `PillMealEditorView` and the per-schedule-row meal picker on the medication editor.

## Goal

A user can create, rename, retime, and delete a `PillMeal` on the iPhone, and assign a scheduled dose to it from the medication editor. Assignment is mutually-aware: changing the meal's target time updates all assigned `ScheduledDose` times; clearing a dose's meal reverts the time to user-controlled.

## Context

- **Parent epic:** 186
- **Predecessor:** the skeleton issue (model + relationship + empty Regimen section).
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` §§ 3 (invariants), 4 (iPhone UX)
- **Files involved:**
  - `PillBreakfast/RegimenTab/PillMealEditorView.swift` (new) — create/edit form.
  - `PillBreakfast/RegimenTab/PillMealsListSection.swift` (new) — extracts the section from `RegimenListView`.
  - `PillBreakfast/RegimenTab/RegimenListView.swift` — render real meals via `@Query` instead of the empty stub.
  - `PillBreakfast/RegimenTab/ScheduleRowEditor.swift` — add a "Belongs to" picker per row.
- **Prior decisions (locked):**
  - Form pacing matches the medication editor (`headlineFont` section headers, `dosageFont` time fields).
  - Delete blocked while ≥ 1 `ScheduledDose` references the meal (same shape as `IngredientDeletion.check`).
  - Picking a meal on a `ScheduleRowEditor` row auto-fills hour/minute from the meal and disables those fields.

## Output Format

A single PR containing:

- [ ] `PillMealEditorView` with name (`TextField`), time (`DatePicker(.hourAndMinute)`), and a Delete affordance gated on no assignments.
- [ ] `PillMealsListSection` on `RegimenListView` — rows show name + target time + assigned-dose count; tap pushes the editor.
- [ ] `ScheduleRowEditor` gains "Belongs to: [None / meal name]" picker; selecting a meal auto-fills hour/minute and disables the inline editors.
- [ ] `PillMealDeletion` helper (mirrors `IngredientDeletion`) with a unit test per outcome.
- [ ] Editor tests: name-required, time round-trips, delete blocked when referenced, time change propagates to assigned doses.

## Examples

```swift
// PillMealDeletion.swift — outcome shape
enum PillMealDeletion {
  enum Outcome { case allowed, referenced }
  static func check(_ meal: PillMeal, in context: ModelContext) throws -> Outcome
}
```

## Constraints

**Scope fence:** iPhone editor + assignment picker only. **No** notification grouping yet (next issue). **No** watch tap-through changes (issue after that).

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** A medication assigned to a meal still fires its existing per-`TimeSlot` notification — the meal-aware grouping is a separate issue. Existing flows behave identically for meals == nil.

## Done-Done

- [ ] All new and existing tests pass on both iOS and watchOS schemes.
- [ ] `pre-commit run --all-files` is clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Closes #<this issue>` and `Refs #186`.

## Labels

`spec-decomposition`, `core`, `phase-4-prn-safety`
