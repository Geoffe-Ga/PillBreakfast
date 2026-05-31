## Role

You are a senior SwiftUI engineer turning the onboarding skeleton's stub sheet into a real first-launch suggestion form: name / save / skip per row, real `PillMeal` persistence on Save, the flag flips on dismiss.

## Goal

The sheet renders one row per suggestion with an editable name field (pre-filled with the heuristic suggestion), the cluster's target time, and the assigned medication names. Tapping Save creates the `PillMeal` and assigns the cluster's `ScheduledDose`s. Skip leaves the row unsaved. The flag flips on dismiss regardless of how many were saved.

## Context

- **Parent epic:** 188
- **Predecessor:** the onboarding skeleton issue.
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` § 8.1 (existing installs)
- **Files involved:**
  - `PillBreakfast/RegimenTab/PillMealOnboardingSheet.swift` — replace stub with real form.
  - `Shared/Onboarding/PillMealOnboardingService.swift` — add a `persist(_:in:)` helper that materialises a `SuggestedMeal` into a `PillMeal` + assigned doses.
  - `PillBreakfastTests/Onboarding/PillMealOnboardingServiceTests.swift` — extend with persistence tests.

## Output Format

A single PR containing:

- [ ] Sheet renders one card per suggestion with:
  - editable `TextField` (default = `suggestedName`),
  - target time (read-only — comes from the cluster),
  - assigned medication names (read-only list).
- [ ] Per-row Save button: creates the `PillMeal` and assigns the dose IDs. Disabled when name is blank.
- [ ] Per-row Skip button: dismisses the row.
- [ ] Dismiss flips `pillMealsOnboarded = true` regardless of save/skip mix.
- [ ] `PillMealOnboardingService.persist(_ suggestion:in:)` is `@MainActor` and throws on save failure.
- [ ] Persistence tests:
  - Saving a suggestion creates a `PillMeal` with the matching target time and the cluster's dose IDs assigned.
  - Saving with a blank name is blocked at the button (Save disabled).
  - Skipping a suggestion leaves no trace.

## Examples

```
We found 2 pill groups in your regimen.

Pill Breakfast        9:30 AM       Vitamin D · Lithium · B12 · Magnesium
  [ Name: Pill Breakfast ]                       [ Skip ]  [ Save ]

Pill Dinner           9:00 PM       Lithium · Lamictal · Sertraline
  [ Name: Pill Dinner ]                          [ Skip ]  [ Save ]

                                                          [ Done ]
```

## Constraints

**Scope fence:** First-launch sheet only. **No** per-add-path inline prompt (next issue). **No** changes to existing add-medication flows.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** A user who skips every row still gets the flag flipped and never sees the sheet again. A user who saves both lands on a Regimen tab with two new meals and their existing scheduled doses re-assigned.

## Done-Done

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #188`.

## Labels

`spec-decomposition`, `core`, `phase-4-prn-safety`
