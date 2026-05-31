## Role

You are a senior SwiftUI engineer adding the "Add to Pill Meal?" inline prompt to every med-add path: `AddMedicationView` save, the search-miss inline create from the ingredient picker, and `ConfirmComponentsView`'s post-import step (bundled multi-med variant for HealthKit).

## Goal

After a med is saved through any of the three paths, the dismiss/redirect step runs the suggestion check. If exactly one existing meal's target time is within 30 min of the new dose's hour:minute, an inline prompt offers Add / Not now. Multiple matches show a quick picker. No matches but ≥ 1 meal exists → "Create new Pill Meal at HH:MM" shortcut. Zero meals → no prompt (the first-launch sheet from issue 2 is the entry point).

## Context

- **Parent epic:** 188
- **Predecessors:** the onboarding skeleton + first-launch sheet (the user has to have ≥ 1 meal for this prompt to fire).
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` § 8.3 (per-add-path), § 8.4 (HealthKit bundled)
- **Files involved:**
  - `Shared/Onboarding/PillMealSuggestion.swift` (new) — pure helper that takes a dose's hour:minute and the existing meals, returns a `Suggestion` enum.
  - `PillBreakfast/RegimenTab/AddMedicationView.swift` — present the prompt after save.
  - `PillBreakfast/RegimenTab/IngredientEditorView.swift` — present the prompt after the search-miss create's save.
  - `PillBreakfast/HealthKitImport/ConfirmComponentsView.swift` — bundled multi-med variant post-import.
- **Prior decisions (locked):**
  - 30-minute window for "this dose looks like that meal."
  - Inline prompt only — not a full sheet. Surfaced via `.confirmationDialog(...)` or a small banner above the form's Save dismiss.
  - HealthKit gets one sheet step that covers all imported meds together (§8.4).

## Output Format

A single PR containing:

- [ ] `PillMealSuggestion` enum with cases `none`, `single(PillMeal)`, `multiple([PillMeal])`, `createNew(hour:minute:)`. Static `propose(forDoseAt:in:)` factory.
- [ ] Single-med save paths (`AddMedicationView`, `IngredientEditorView` create) present a `.confirmationDialog` with the suggestion options.
- [ ] HealthKit import: after `performImport()` saves, a final sheet step lists every imported med with a per-row meal picker (or "None") and a Save / Skip all bottom bar.
- [ ] Tests:
  - `propose(...)` returns `single` for a 9:00 dose with a 9:00 meal.
  - `propose(...)` returns `multiple` for a 9:00 dose with both a 8:50 and a 9:10 meal.
  - `propose(...)` returns `createNew` for a 9:00 dose with meals only at 18:00 and 21:00.
  - `propose(...)` returns `none` when no meals exist (the first-launch sheet is the entry point in that case).
  - HealthKit bundled view test: 3 imports → 3 rows; saving assigns only the rows the user picked a meal for.

## Examples

```swift
public enum PillMealSuggestion: Sendable, Hashable {
  case none
  case single(PillMeal)
  case multiple([PillMeal])
  case createNew(hour: Int, minute: Int)
}
```

## Constraints

**Scope fence:** Auto-suggest only. **No** redesign of the existing add-medication flow. **No** watch-side surface.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** A user with zero meals adds a medication and sees the existing flow with no new prompts. A user with at least one meal sees the inline prompt on every add path that produces a dose in the 30-min window.

## Done-Done

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #188`.

## Labels

`spec-decomposition`, `core`, `phase-4-prn-safety`
