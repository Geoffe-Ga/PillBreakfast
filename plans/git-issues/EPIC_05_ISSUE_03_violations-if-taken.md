## Role

You are the senior Swift engineer responsible for the function that prevents Geoff from accidentally taking 5000mg of acetaminophen across three different products. You write code that is easy to read aloud and defended by tests that the user would actually recognize.

## Goal

Implement `violationsIfTaken(_:quantity:at:)` per SPEC §5.3 returning a typed `[Violation]` enum. Cover both daily-ceiling and min-interval cases. Land all three Phase 4 gate test cases as automated tests, including the killer cross-product safety test (1500mg standalone Tylenol + 4 tablets Excedrin Extra Strength -> acetaminophen daily-ceiling violation).

## Context

- **Parent epic:** #5
- **Predecessor issue(s):** #EPIC_05_ISSUE_02_NUMBER (the query helpers this function depends on).
- **SPEC section:** `plans/SPEC.md` §5.3 (Ceiling/interval logic pseudocode, lines 235-260), §10 Phase 4 (gate test cases, lines 453-456).
- **Files involved (new):**
  - `Shared/Safety/Violation.swift` — the enum.
  - `Shared/Safety/SafetyEvaluator.swift` — `violationsIfTaken(_:quantity:at:in:)`.
  - `PillBreakfastTests/Safety/SafetyEvaluatorTests.swift` — the three gate scenarios.
- **Prior decisions (locked):**
  - **Violations are typed**, not `String` messages. The enum's associated values carry the ingredient and the numbers; UI shapes the wording.
  - **Aggregate by ingredient, not product.** This is the entire point of the ingredient layer. SPEC §5.1.
  - Returning an empty array means "no violations." A non-empty array means "show the soft warning interstitial, naming each ingredient."
- **State of the world:** EPIC_05_ISSUE_02 merged; query helpers ready.

## Output Format

A single PR containing:

- [ ] `public enum Violation: Sendable, Hashable { case ceiling(Ingredient, current: Double, proposed: Double, ceiling: Double); case tooSoon(Ingredient, lastTakenAt: Date, minInterval: Int) }`.
- [ ] `SafetyEvaluator.violationsIfTaken(_ medication: Medication, quantity: Int, at now: Date, in context: ModelContext) throws -> [Violation]` mirroring SPEC §5.3's pseudocode.
- [ ] **Three required tests (the Phase 4 gate):**
  - `testGabapentinSelfPacing` — gabapentin daily-ceiling check fires when cumulative would exceed.
  - `testTylenolSelfPacing` — min-interval check fires when re-dosing too soon.
  - `testCrossProductTylenolPlusExcedrinCeiling` — 1500mg Tylenol + 4 tablets Excedrin (1000mg APAP) triggers the acetaminophen ceiling.
- [ ] Additional negative tests: no violations on cleared regimen; both violations stack on a worst-case dose.

## Examples

```swift
public enum Violation: Sendable, Hashable, Identifiable {
    case ceiling(ingredient: Ingredient, current: Double, proposed: Double, ceiling: Double)
    case tooSoon(ingredient: Ingredient, lastTakenAt: Date, minInterval: Int)

    public var id: String {
        switch self {
        case .ceiling(let ing, _, _, _): return "ceiling:\(ing.id)"
        case .tooSoon(let ing, _, _): return "tooSoon:\(ing.id)"
        }
    }
}

@MainActor
public enum SafetyEvaluator {
    public static func violationsIfTaken(
        _ medication: Medication,
        quantity: Int,
        at now: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [Violation] {
        var violations: [Violation] = []
        for component in medication.components {
            guard let ingredient = component.ingredient else { continue }
            let addedMg = Double(quantity) * component.dosagePerUnitMg

            if let ceiling = ingredient.dailyCeilingMg {
                let todayMg = try IngredientQueries.totalToday(ingredient: ingredient, in: context, at: now, calendar: calendar)
                if todayMg + addedMg > ceiling {
                    violations.append(.ceiling(ingredient: ingredient, current: todayMg, proposed: todayMg + addedMg, ceiling: ceiling))
                }
            }

            if let minInterval = ingredient.minIntervalMinutes,
               let lastDose = try IngredientQueries.lastDoseTime(ingredient: ingredient, in: context, before: now),
               now.timeIntervalSince(lastDose) < Double(minInterval * 60) {
                violations.append(.tooSoon(ingredient: ingredient, lastTakenAt: lastDose, minInterval: minInterval))
            }
        }
        return violations
    }
}
```

The killer test:

```swift
func testCrossProductTylenolPlusExcedrinCeiling() throws {
    let context = try makeInMemoryContext()
    let apap = Ingredient(name: "Acetaminophen", isHighRisk: false, dailyCeilingMg: 4000, minIntervalMinutes: 240)
    context.insert(apap)

    let tylenol = makeMed(named: "Tylenol", components: [(apap, 500)], context: context)
    let excedrin = makeMed(named: "Excedrin Extra Strength",
                           components: [(apap, 250), (makeAspirin(in: context), 250), (makeCaffeine(in: context), 65)],
                           context: context)

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    // 3 tablets of Tylenol Extra Strength = 1500mg acetaminophen, 5 hours ago
    insert(.takenEvent(tylenol, quantity: 3, ingredientID: apap.id, ingredientName: "Acetaminophen", totalMg: 1500, at: now.addingTimeInterval(-5 * 3600), in: context))

    let violations = try SafetyEvaluator.violationsIfTaken(excedrin, quantity: 4, at: now, in: context)
    let ceilingViolation = violations.first { if case .ceiling = $0 { return true } else { return false } }
    XCTAssertNotNil(ceilingViolation, "Acetaminophen ceiling should be tripped by 1500 + (4 * 250) = 2500. Wait — 1500 + 1000 = 2500, which is under 4000. Fix the fixture.")
    // (Adjust the fixture so the killer test legitimately trips the ceiling; e.g., bump prior Tylenol dose to 3500mg.)
}
```

> **Implementer note on the killer test fixture:** SPEC §10 Phase 4 case 3 phrases the scenario as "1500mg standalone Tylenol + 4 Excedrin Extra Strength = ceiling tripped." Doing the arithmetic: 1500 + (4 * 250) = 2500, which is under 4000. To make the test actually trip the ceiling, increase one side. Recommended fixture: **3500mg prior Tylenol + 2 Excedrin = 4000mg + threshold; raise to 4500.** Or **1500mg Tylenol + 12 Excedrin = 1500 + 3000 = 4500.** Pick whichever is more readable in the test name. Document the adjustment in the PR; this is a SPEC-reference reconciliation, not a logic change. **Flag this as Gap 1 in the final spec-decomposition report.**

## Constraints

**Scope fence:** Do not surface the warning in any UI — EPIC_05_ISSUE_05. Do not wire it into `DoseEventWriter` yet — that happens implicitly when EPIC_05_ISSUE_05's interstitial calls this evaluator before writing.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Pure logic addition; no UI change.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes), including the three Phase 4 gate tests.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #5` and `Closes #EPIC_05_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-4-prn-safety`.
