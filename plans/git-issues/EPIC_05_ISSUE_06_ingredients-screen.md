## Role

You are a senior SwiftUI engineer adding the iPhone Ingredients screen. You understand that this is the screen where the user takes responsibility for the thresholds the safety system enforces.

## Goal

Add an Ingredients screen on iPhone (reachable from the Regimen edit view and from Settings) listing every `Ingredient` and letting the user edit `dailyCeilingMg`, `minIntervalMinutes`, and `isHighRisk`. The seeded-ingredient disclaimer from EPIC_02_ISSUE_03 (`IngredientLibrarySeeder.disclaimer`) appears prominently at the top. Edits sync to the watch via the existing `RegimenSnapshot` channel.

## Context

- **Parent epic:** #5
- **Predecessor issue(s):** #EPIC_05_ISSUE_05_NUMBER.
- **SPEC section:** `plans/SPEC.md` §5.3 (seeded library + disclaimer), §6.1 (Ingredients screen, accessed from settings or the Regimen edit view).
- **Files involved (new):**
  - `iOSApp/RegimenTab/IngredientsListView.swift`
  - `iOSApp/RegimenTab/IngredientEditorView.swift`
  - `iOSApp/SettingsTab/SettingsView.swift` — add a navigation row to Ingredients.
  - `iOSApp/RegimenTab/EditMedicationView.swift` — add "Manage ingredients" navigation entry.
- **Prior decisions (locked):**
  - **Disclaimer is non-dismissible.** It stays at the top of `IngredientsListView` permanently; the user does not get to hide it.
  - **`isHighRisk` toggling cascades.** When the user toggles an ingredient to high-risk, any medication containing it becomes high-risk on the next view-of-tap-through (no migration required — `Medication.isHighRisk` is computed). Surface this in the editor copy: "Toggling this on requires press-and-hold for every product containing it."
  - **No deletion of seeded ingredients.** User-added ingredients can be deleted (if not referenced by any `MedicationComponent`).
- **State of the world:** PRN safety logic and warnings work end-to-end. The user can configure the regimen but not the ingredient thresholds.

## Output Format

A single PR containing:

- [ ] `IngredientsListView` with the disclaimer banner, list of ingredients, swipe-to-delete (only for user-added, unreferenced).
- [ ] `IngredientEditorView` with `dailyCeilingMg`, `minIntervalMinutes` (as a stepper or formatted text field), `isHighRisk` toggle.
- [ ] Navigation entry from Settings and from Edit Medication.
- [ ] Sync: on save, regenerate the snapshot and push to the watch.
- [ ] Tests: cannot-delete-referenced-ingredient validation; cannot-delete-seeded validation; high-risk-toggle round trip via snapshot.

## Examples

Edit form copy:

```
Ingredient: Acetaminophen
Aliases: Paracetamol, APAP

Daily ceiling (mg)
[ 4000 ]   - leave blank for none

Minimum interval (minutes)
[ 240 ]    - 4 hours

[ ] High risk
    Toggling on requires press-and-hold for every product containing this ingredient.

⚠ The suggested thresholds above are starting points. Not medical advice.
   Confirm every ceiling and interval with your prescriber.
```

## Constraints

**Scope fence:** No watch UI for editing ingredients (the watch never edits the regimen). No bulk-edit. No CSV import.

**Disclaimer is not optional.** Removing or hiding it must be rejected at review.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** End of EPIC 05. PRN safety works end-to-end; user can configure ingredients on iPhone; the three Phase 4 gate tests pass; the killer test runs to its conclusion.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #5` and `Closes #EPIC_05_ISSUE_06_NUMBER`.

## Labels

`spec-decomposition`, `edges`, `phase-4-prn-safety`.
