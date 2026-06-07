# RCA — Issue #256: tapping "+" (Add medication) crashes the app (Debug)

- **Date:** 2026-06-07
- **Component:** iOS `RegimenTab` / `AddMedicationView`
- **Severity:** High for dev/dogfooding (add-medication flow unusable in Debug); not user-facing in Release.

## Problem Statement

On the iPhone **Regimen** tab, tapping the **+ ("Add medication")** toolbar button crashes the app to the home screen in Debug builds. The "New Medication" sheet never appears.

- **Signal:** `EXC_BREAKPOINT (SIGTRAP)` during `UISheetPresentationController presentationTransitionWillBegin` → SwiftUI body update.
- **Symbolicated top frame:** `AddMedicationView.suggestionActions() (AddMedicationView.swift:95)`.

## Root Cause

`AddMedicationView.swift:95` — an `assertionFailure(...)` inside the `suggestionActions()` `@ViewBuilder` that backs the `.confirmationDialog`:

```swift
case .some(.noMeals), nil:
  let _ = assertionFailure("suggestion dialog presented with no-meals/nil state")
  EmptyView()
```

SwiftUI evaluates a `confirmationDialog`'s **actions builder eagerly** during the body / presentation pass — **regardless of `isPresented`**. When the Add-medication sheet first presents, `suggestion == nil` (its `@State` initial value), so the `switch` falls into `case .some(.noMeals), nil:` and executes `assertionFailure`, which traps in Debug.

## Analysis — why the assumption was wrong

The branch carried a comment asserting it was "Unreachable: `presentSuggestionOrDismiss` finishes on `.noMeals` and never sets `suggestion` to nil while the dialog is up." That reasoning only holds *while the dialog is presented*. It misses that SwiftUI builds the actions closure **eagerly, before/independent of presentation**, when `suggestion` is still its default `nil`. So `nil` is the normal resting state of the builder, not an invariant violation.

## Impact

- Every tap of the Regimen "+" traps in Debug → the entire add-medication flow is unusable for local development and dogfooding.
- Release builds compile `assertionFailure` to a no-op, so end users on TestFlight/App Store would *not* crash — the dialog would simply build an empty actions list while `nil`. Debug-only, but total for the dev workflow.

## Contributing Factors — why it wasn't caught

- Introduced by #210 ("auto-suggest Add to Pill Meal?"), which added the dialog. The earlier `MemoryReproUITests` add-flow driver predates #210, so no automated test exercised the new dialog's presentation.
- No UI test asserted that tapping "+" presents the form.
- The mistaken "unreachable" reasoning made the `assertionFailure` look intentional/safe in review.

## Fix Strategy

**Chosen:** Remove the `assertionFailure` from the eagerly-evaluated builder; render `EmptyView()` quietly for `.noMeals` / `nil`. The actions builder must be a pure, side-effect-free view builder that tolerates the default `nil` state.

Rejected alternatives:
- *Gate the whole dialog behind `if suggestion != nil`* — doesn't help; SwiftUI still evaluates the builder, and it complicates the binding-driven presentation.
- *Keep the assertion but in a non-builder code path* — the invariant it tried to express ("dialog shown with no actionable suggestion") is better enforced by `presentSuggestionOrDismiss`, which already `finish()`es on `.noMeals` and never presents in that state.

## Prevention

- Never put `assertionFailure` / side effects in a SwiftUI `@ViewBuilder` (especially `confirmationDialog`/`alert`/`sheet` action builders) — they are evaluated eagerly and on the default state.
- Regression guard: `RegimenAddMedicationUITests.testTappingAddMedicationPresentsFormWithoutCrashing` taps "+" and asserts the form appears with the app still in foreground.
