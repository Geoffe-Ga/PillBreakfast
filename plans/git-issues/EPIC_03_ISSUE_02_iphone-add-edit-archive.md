## Role

You are a senior SwiftUI engineer building the iPhone Regimen tab's editing surface. You care about form ergonomics, validation that fails fast, and the architectural rule that the iPhone never gets logging UI.

## Goal

Add the iPhone Regimen tab's add / edit / archive flows for **maintenance** medications: a `+` button in the toolbar opens an `AddMedicationView` form (name, form, one-ingredient component, schedule rows); tapping a row opens `EditMedicationView` with the same form pre-filled; swipe-to-archive soft-deletes (sets `Medication.isArchived = true`). The watch reflects all changes within 5 seconds via the EPIC_02_ISSUE_05 push channel.

PRN configuration is intentionally stubbed in this issue — a "PRN configured in a later phase" placeholder is fine. EPIC 05 fills it in.

## Context

- **Parent epic:** #3
- **Predecessor issue(s):** #EPIC_03_ISSUE_01_NUMBER (Regimen list view exists), #EPIC_02_ISSUE_05_NUMBER (sync channel).
- **SPEC section:** `plans/SPEC.md` §6.1 (Regimen tab, maintenance subset, lines 270-281).
- **Files involved (new):**
  - `iOSApp/RegimenTab/AddMedicationView.swift`
  - `iOSApp/RegimenTab/EditMedicationView.swift`
  - `iOSApp/RegimenTab/MedicationFormState.swift` — `@Observable` form-state object (not a model) capturing fields and validation.
  - `iOSApp/RegimenTab/ScheduleRowEditor.swift` — sub-view for adding `ScheduledDose`s.
- **Files updated:**
  - `iOSApp/RegimenTab/RegimenListView.swift` — add toolbar `+`, row tap navigation, swipe action.
  - `Shared/Sync/WatchConnectivityCoordinator.swift` — hook a "push after save" trigger if not already in place from EPIC_02_ISSUE_05.
- **Prior decisions (locked):**
  - `Medication.isArchived` is the swipe target; we soft-delete. Hard-delete only via Settings "Forget this medication" (out of scope here; v1.x).
  - Validation: `displayName` non-empty; at least one `MedicationComponent` with `dosagePerUnitMg > 0`; at least one `ScheduledDose` for maintenance meds (PRN can have zero schedules).
  - For single-ingredient maintenance meds (the common case), the form auto-fills the component count to 1 and binds it to a single ingredient picker drawing from the seeded library + a "+ New ingredient" affordance that opens a one-screen sub-form.
- **State of the world:** EPIC 03 skeleton has landed. The Regimen tab shows the stub medication but cannot be edited.

## Output Format

A single PR containing:

- [ ] `AddMedicationView` with name, form picker, ingredient picker (drawing from `Ingredient` `@Query`), `dosagePerUnitMg` field, schedule row editor.
- [ ] `EditMedicationView` reusing the same form bound to an existing `Medication`.
- [ ] Swipe-to-archive on `RegimenListView` rows.
- [ ] `MedicationFormState` validation surfacing errors inline; the save button is disabled until valid.
- [ ] Auto-push to watch on save via the existing `WatchConnectivityCoordinator`.
- [ ] Unit tests on `MedicationFormState`: empty name invalid; component with zero mg invalid; maintenance with zero schedules invalid; valid happy path.

## Examples

`MedicationFormState` outline:

```swift
@MainActor
@Observable
final class MedicationFormState {
    var displayName: String = ""
    var unitForm: MedicationForm = .tablet
    var componentDraft: ComponentDraft = .empty
    var schedules: [ScheduleDraft] = []
    var kind: MedicationKind = .maintenance

    var validationErrors: [String] {
        var errs: [String] = []
        if displayName.trimmingCharacters(in: .whitespaces).isEmpty { errs.append("Name required.") }
        if componentDraft.dosagePerUnitMg <= 0 { errs.append("Dosage per unit must be greater than zero.") }
        if kind == .maintenance && schedules.isEmpty { errs.append("Add at least one scheduled time.") }
        return errs
    }
    var isValid: Bool { validationErrors.isEmpty }
}
```

Manual checklist:

1. Tap `+`. Form opens. Try to save with no name -> button disabled, error shown.
2. Enter "Vitamin D", pick "Cholecalciferol" from the seeded library, dosage 2000mg, schedule 8:00 AM daily. Save.
3. Vitamin D appears under Maintenance on iPhone and on the watch within 5 seconds.
4. Swipe Vitamin D row to archive. It disappears from the iPhone list, and from the watch within 5 seconds.

## Constraints

**Scope fence:** Do not implement PRN configuration UI — it's a stub here, EPIC 05 fills it in. Do not implement the Ingredients screen — EPIC 05. Do not implement HealthKit import — EPIC 07. Do not write notification code — EPIC_03_ISSUE_04. Do not write `DoseEvent`s — EPIC_03_ISSUE_03.

**iPhone never gets logging UI.** No "Mark Taken" affordance. No "I just took this" button. The edit form is for the *regimen*, not for logging today's dose.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The watch continues to render the synced regimen list and pending-queue placeholder. The iPhone now adds + edits + archives medications and pushes changes within 5 seconds.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair; the manual checklist above completes.
- [ ] PR opened with `Refs #3` and `Closes #EPIC_03_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-2-maintenance`.
