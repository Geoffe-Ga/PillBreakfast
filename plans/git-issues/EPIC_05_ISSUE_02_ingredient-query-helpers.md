## Role

You are a senior Swift engineer writing the pure query helpers that the entire ingredient-safety system rests on. You care about determinism, test coverage, and reading from the **denormalized** `DoseEvent.ingredientAmounts` rather than re-deriving through the live `Medication -> components -> ingredient` graph.

## Goal

Implement `totalToday(ingredient:in:at:)` and `lastDoseTime(ingredient:in:)` in `Shared/Queries/`. Both operate over the `LoggedIngredientAmount` snapshots stored on `DoseEvent`. Cover the timezone edge case (the day boundary is the user's local calendar) and the multi-product case (one `Ingredient` may appear in many `DoseEvent`s across many products).

## Context

- **Parent epic:** #5
- **Predecessor issue(s):** #EPIC_05_ISSUE_01_NUMBER (skeleton).
- **SPEC section:** `plans/SPEC.md` §5.3 (Design Notes — denormalization rationale), §10 Phase 4 ("`totalToday(ingredient:)` and `lastDoseTime(ingredient:)` query helpers operating on the denormalized `LoggedIngredientAmount` snapshots").
- **Files involved (new):**
  - `Shared/Queries/IngredientQueries.swift`.
  - `PillBreakfastTests/Queries/IngredientQueriesTests.swift`.
- **Prior decisions (locked):**
  - **Read from `DoseEvent.ingredientAmounts`, not from `medication.components`.** Editing a product's composition later must not retroactively change historical totals. SPEC §5.3, CLAUDE.md.
  - "Today" is the user's local calendar day. Calendar is injected for testability.
  - `status == .taken` only — `.skipped` and `.snoozed` do not contribute to running totals.
- **State of the world:** EPIC_05_ISSUE_01 is merged. PRN list rows still show stubs.

## Output Format

A single PR containing:

- [ ] `IngredientQueries.totalToday(ingredient:in:at:calendar:)` returning `Double` (mg).
- [ ] `IngredientQueries.lastDoseTime(ingredient:in:before:)` returning `Date?`.
- [ ] Comprehensive tests covering: single-product accumulation; multi-product accumulation (Tylenol + Excedrin both contribute to acetaminophen); ignored `.skipped` / `.snoozed` events; midnight boundary; alternate timezone via injected `Calendar`.

## Examples

```swift
@MainActor
public enum IngredientQueries {
    public static func totalToday(
        ingredient: Ingredient,
        in context: ModelContext,
        at now: Date,
        calendar: Calendar = .current
    ) throws -> Double {
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = #Predicate<DoseEvent> { event in
            event.status == DoseStatus.taken && event.takenAt >= startOfDay && event.takenAt <= now
        }
        let events = try context.fetch(FetchDescriptor<DoseEvent>(predicate: predicate))
        return events.flatMap { $0.ingredientAmounts }
            .filter { $0.ingredientID == ingredient.id }
            .map { $0.totalMg }
            .reduce(0, +)
    }

    public static func lastDoseTime(
        ingredient: Ingredient,
        in context: ModelContext,
        before now: Date
    ) throws -> Date? {
        let predicate = #Predicate<DoseEvent> { event in
            event.status == DoseStatus.taken && event.takenAt <= now
        }
        var descriptor = FetchDescriptor<DoseEvent>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.takenAt, order: .reverse)]
        let events = try context.fetch(descriptor)
        for event in events where event.ingredientAmounts.contains(where: { $0.ingredientID == ingredient.id }) {
            return event.takenAt
        }
        return nil
    }
}
```

Key test:

```swift
func testTotalTodaySumsAcrossMultipleProducts() throws {
    let context = try makeInMemoryContext()
    let apap = Ingredient(name: "Acetaminophen", isHighRisk: false, dailyCeilingMg: 4000, minIntervalMinutes: 240)
    let tylenol = Medication(displayName: "Tylenol", kind: .prn, ...)
    let excedrin = Medication(displayName: "Excedrin", kind: .prn, ...)
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    insert(.takenEvent(tylenol, amounts: [.init(ingredientID: apap.id, ingredientName: "Acetaminophen", totalMg: 1000)], at: now.addingTimeInterval(-3600)))
    insert(.takenEvent(excedrin, amounts: [.init(ingredientID: apap.id, ingredientName: "Acetaminophen", totalMg: 500)], at: now.addingTimeInterval(-1800)))

    let total = try IngredientQueries.totalToday(ingredient: apap, in: context, at: now)
    XCTAssertEqual(total, 1500)
}
```

## Constraints

**Scope fence:** Do not implement `violationsIfTaken` — EPIC_05_ISSUE_03. Do not change `DoseEventWriter` or any UI. Do not surface the totals in the PRN list yet — EPIC_05_ISSUE_04 wires them in.

**Reading through `medication.components` is forbidden.** Re-running this query after the user edits a product's composition must return the same historical total. The denormalization is the contract.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No UI change; pure helpers added, fully tested.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #5` and `Closes #EPIC_05_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-4-prn-safety`.
