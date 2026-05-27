## Role

You are a senior iOS engineer responsible for the mapping that turns a Health medication into a PillBreakfast `Medication` without losing fidelity or skipping the manual ingredient confirmation step.

## Goal

Implement `HealthMedicationMapper.toDraft(_ draft: HealthMedicationDraft) -> MedicationDraft` and surface a "Confirm components" step that runs once per import. The user picks the active ingredient(s) from the seeded library (or adds a new one). Save persists a new `Medication` with `healthKitConceptID` set.

## Context

- **Parent epic:** #7
- **Predecessor issue(s):** #EPIC_07_ISSUE_03_NUMBER.
- **SPEC section:** `plans/SPEC.md` §6.1 ("ingredient components must be confirmed manually because Health doesn't expose composition reliably"), §10 Phase 6.
- **Files involved (new):**
  - `iOSApp/HealthKitImport/HealthMedicationMapper.swift`.
  - `iOSApp/HealthKitImport/ConfirmComponentsView.swift`.
- **Prior decisions (locked):**
  - **Ingredient mapping is user-confirmed.** Auto-fill the obvious match for single-ingredient names ("Lithium" -> seeded "Lithium Carbonate" if present, else prompt to create), but always show the screen for confirmation.
  - **`healthKitConceptID` is set on save.** This is the dedupe key for re-imports.
  - The scheduled times from Health become `ScheduledDose` rows; `daysOfWeek = []` (every day) unless Health provides specific weekday data.
- **State of the world:** Import sheet shows selectable Health medications.

## Output Format

A single PR containing:

- [ ] `HealthMedicationMapper.toDraft(...)` returning a `MedicationDraft` that already has the schedule filled in.
- [ ] `ConfirmComponentsView` showing the seeded library + "Add new ingredient" affordance per imported medication.
- [ ] Save inserts a `Medication` with `healthKitConceptID` set and triggers a snapshot push to the watch.
- [ ] Tests: mapper produces correct draft for fixtures with single time, multiple times; ingredient suggestion picks the obvious seeded match.

## Constraints

**Scope fence:** No idempotency check — EPIC_07_ISSUE_05.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Import flow works end-to-end except duplicates may be re-created on re-import (fixed in next issue).

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #7` and `Closes #EPIC_07_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-6-healthkit`.
