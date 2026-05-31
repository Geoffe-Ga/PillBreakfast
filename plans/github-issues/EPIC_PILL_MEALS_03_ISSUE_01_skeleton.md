## Role

You are a senior Swift engineer skeletonizing the Pill Meals onboarding pipeline: a clustering helper that proposes meals from existing schedules, the `pillMealsOnboarded` preference flag, and a stub first-launch sheet that prints clusters without persisting.

## Goal

`PillMealOnboardingService.suggestions(from:calendar:)` returns `[SuggestedMeal]` by clustering `ScheduledDose`s within 30 min of each other. `UserPreferences.pillMealsOnboarded: Bool` exists with a default of `false`. The Regimen tab presents a stub sheet on first appearance when the flag is `false` and ≥ 1 suggestion exists; the sheet prints the suggestions and a Done button that flips the flag.

## Context

- **Parent epic:** 188
- **Predecessor:** the Foundation epic's editor issue must be in `main` (so the sheet has something to write into eventually).
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` §§ 8.1 (existing installs), 8.2 (new installs)
- **Files involved:**
  - `Shared/Onboarding/PillMealOnboardingService.swift` (new) — clustering helper.
  - `Shared/Preferences/UserPreferences.swift` — add `pillMealsOnboarded: Bool = false`.
  - `PillBreakfast/RegimenTab/PillMealOnboardingSheet.swift` (new) — stub sheet.
  - `PillBreakfast/RegimenTab/RegimenListView.swift` — present the sheet on first appear.
  - `PillBreakfastTests/Onboarding/PillMealOnboardingServiceTests.swift` (new) — clustering tests.

## Output Format

A single PR containing:

- [ ] `PillMealOnboardingService` value type with a pure static `suggestions(from doses: [ScheduledDose], calendar: Calendar) -> [SuggestedMeal]`. Clusters doses whose `hour:minute` are within 30 min of each other; minimum 2 doses per cluster.
- [ ] `SuggestedMeal { let suggestedName: String; let hour: Int; let minute: Int; let doseIDs: [UUID] }`. Name suggestion is purely heuristic (e.g., 5–11 → "Pill Breakfast", 11–16 → "Pill Lunch", 16–22 → "Pill Dinner", else → "Pill Meal at HH:MM").
- [ ] `UserPreferences.pillMealsOnboarded` defaults `false`, round-trips through `UserPreferencesStore`.
- [ ] `PillMealOnboardingSheet` (stub) prints each suggestion as a row and includes a Done button that sets the flag. **No** persistence of the meals yet.
- [ ] `RegimenListView` presents the sheet when `!pillMealsOnboarded` and `!suggestions.isEmpty` on first appear.
- [ ] Clustering tests: two doses 15 min apart cluster; two doses 35 min apart don't; single-dose cluster is filtered out; multiple clusters round-trip.

## Examples

```swift
public struct SuggestedMeal: Sendable, Hashable {
  public let suggestedName: String  // "Pill Breakfast"
  public let hour: Int
  public let minute: Int
  public let doseIDs: [UUID]
}
```

## Constraints

**Scope fence:** Skeleton only. **No** actual `PillMeal` persistence from the sheet (that's the next issue). **No** per-add-path inline prompt (issue after that).

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Existing users land on the Regimen tab and see either the sheet (with their clusters) or no sheet at all — never a broken state. The flag flips on dismiss so it doesn't fire twice.

## Done-Done

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #188`.

## Labels

`spec-decomposition`, `tracer-code`, `phase-4-prn-safety`
