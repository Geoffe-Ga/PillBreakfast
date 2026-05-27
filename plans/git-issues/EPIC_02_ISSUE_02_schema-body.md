## Role

You are a senior Swift engineer fluent in SwiftData relationships, Swift 6 strict concurrency, and the trade-offs around `Sendable` conformance for reference-typed `@Model` classes.

## Goal

Fill in the full schema body from SPEC §5.2 on the five `@Model` classes scaffolded in EPIC_02_ISSUE_01: all stored properties, all relationships (with `deleteRule: .cascade` and `inverse:`), and the computed `Medication.isHighRisk` property. Achieve Swift 6 strict-concurrency compliance without `@unchecked Sendable`. Add unit tests proving the relationships hold and cascade deletes work.

## Context

- **Parent epic:** #2
- **Predecessor issue(s):** #EPIC_02_ISSUE_01_NUMBER (skeleton model graph).
- **SPEC section:** `plans/SPEC.md` §5.2 (Schema, lines 128-221) — implement verbatim, including the comment text. §5.3 (Design Notes, lines 223-263) — read for context on denormalization and `isHighRisk`.
- **Files updated:** `Shared/Models/Ingredient.swift`, `MedicationComponent.swift`, `Medication.swift`, `ScheduledDose.swift`, `DoseEvent.swift`.
- **Files new:** `PillBreakfastTests/Models/ModelGraphTests.swift`.
- **Prior decisions (locked):**
  - `DoseEvent.ingredientAmounts: [LoggedIngredientAmount]` is **denormalized**. The snapshot is filled at log time. **Do not** make it a computed property over the live `medication.components` relationship. (SPEC §5.3, CLAUDE.md.)
  - `Medication.isHighRisk` is a computed property over `components` — there is no stored `isHighRisk` on `Medication`. (SPEC §5.3.)
  - `Medication.healthKitConceptID` is nullable and populated **only** for Health-imported meds (CLAUDE.md). Keep the field; EPIC 07 populates it.
- **State of the world:** EPIC_02_ISSUE_01 has landed. Models have only `id`; nothing else.

## Output Format

A single PR containing:

- [ ] Full schema body per SPEC §5.2 on all five `@Model` classes, including the inline comments where they clarify intent (e.g., the comment block on `DoseEvent.ingredientAmounts` explaining the snapshot-at-log-time design).
- [ ] `Medication.isHighRisk` as a computed property exactly as in SPEC §5.2 line 179.
- [ ] Initializers that take all required fields and reasonable defaults for collections (`[]`) and booleans (`false`).
- [ ] `ModelGraphTests` covering: relationship round-trip (Medication <-> components, schedule, doseEvents), cascade delete (deleting a Medication deletes its components, schedule, and dose events), `isHighRisk` is true iff any ingredient's `isHighRisk` is true.
- [ ] Swift 6 strict-concurrency check passes without `@unchecked Sendable`. Where `Sendable` conformance is needed at boundaries (e.g. passing to `Task`), use immutable value-type DTOs in EPIC_02_ISSUE_04, not the `@Model` classes.

## Examples

`Medication.isHighRisk` test:

```swift
func testMedicationIsHighRiskWhenAnyIngredientIsHighRisk() throws {
    let context = try makeInMemoryContext()
    let lithium = Ingredient(name: "Lithium Carbonate", aliases: [], isHighRisk: true)
    let dye = Ingredient(name: "Inactive Dye", aliases: [], isHighRisk: false)
    let lithobid = Medication(displayName: "Lithobid 300mg", unitForm: .tablet, kind: .maintenance)
    lithobid.components = [
        MedicationComponent(ingredient: lithium, dosagePerUnitMg: 300),
        MedicationComponent(ingredient: dye, dosagePerUnitMg: 1),
    ]
    XCTAssertTrue(lithobid.isHighRisk)

    let vitaminD = Ingredient(name: "Cholecalciferol", aliases: [], isHighRisk: false)
    let vitaminMed = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    vitaminMed.components = [MedicationComponent(ingredient: vitaminD, dosagePerUnitMg: 2000)]
    XCTAssertFalse(vitaminMed.isHighRisk)
}
```

Cascade delete test (abridged):

```swift
func testDeletingMedicationCascadesToComponentsAndDoseEvents() throws {
    let context = try makeInMemoryContext()
    let med = Medication.makeSample(context: context)  // helper inserts med + 2 components + 1 dose event
    let medID = med.id

    context.delete(med)
    try context.save()

    let components = try context.fetch(FetchDescriptor<MedicationComponent>())
    let doseEvents = try context.fetch(FetchDescriptor<DoseEvent>())
    XCTAssertTrue(components.allSatisfy { $0.medication?.id != medID })
    XCTAssertTrue(doseEvents.allSatisfy { $0.medication?.id != medID })
}
```

## Constraints

**Scope fence:** Do not seed the ingredient library — EPIC_02_ISSUE_03. Do not add `RegimenSnapshot` — EPIC_02_ISSUE_04. Do not write any sync code — EPIC_02_ISSUE_05. Do not add UI — EPIC 03.

**Denormalization is load-bearing.** `DoseEvent.ingredientAmounts` must be a stored `[LoggedIngredientAmount]`, not a computed property. SPEC §5.3 explains the reasoning at length; CLAUDE.md flags this as a non-obvious convention worth preserving. A PR that re-derives this on read must be rejected.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No UI changes; placeholder views still render. The container now has a full schema, but only test code reads or writes it.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #2` and `Closes #EPIC_02_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-1-data-model`, `concurrency`.
