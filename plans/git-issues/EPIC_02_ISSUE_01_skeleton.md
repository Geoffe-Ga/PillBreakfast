## Role

You are a senior Swift engineer wiring the SwiftData schema skeleton for PillBreakfast. You understand `@Model`, `@Relationship`, and the migration implications of changing a model graph.

## Goal

Add empty `@Model` class shells in `Shared/Models/` for `Ingredient`, `MedicationComponent`, `Medication`, `ScheduledDose`, and `DoseEvent`, plus the supporting struct (`LoggedIngredientAmount`) and enums (`MedicationKind`, `MedicationForm`, `DoseStatus`, `LogSource`). Each class has only its `@Attribute(.unique) var id: UUID` and an initializer. No real fields beyond `id`, no relationships, no domain logic. The `Schema(...)` in `PersistenceController` is updated to include all five model types so the container actually has tables to migrate into.

This is the skeleton issue for EPIC 02: it proves the model graph compiles, the container migrates cleanly, and the tracer-code system stays demoable. The full schema body from SPEC §5.2 lands in EPIC_02_ISSUE_02.

## Context

- **Parent epic:** #2
- **Predecessor issue(s):** #EPIC_01_ISSUE_03_NUMBER (full EPIC 01 must be merged).
- **SPEC section:** `plans/SPEC.md` §5.2 (Schema, lines 128-221) — only the class names and `id` properties are in scope for this issue.
- **Files involved (new):**
  - `Shared/Models/Ingredient.swift`
  - `Shared/Models/MedicationComponent.swift`
  - `Shared/Models/Medication.swift`
  - `Shared/Models/ScheduledDose.swift`
  - `Shared/Models/DoseEvent.swift`
  - `Shared/Models/LoggedIngredientAmount.swift` (the struct)
  - `Shared/Models/Enums.swift` (the four enums)
- **Files updated:**
  - `Shared/Persistence/PersistenceController.swift` — `Schema([Ingredient.self, MedicationComponent.self, Medication.self, ScheduledDose.self, DoseEvent.self])`.
- **Prior decisions (locked):**
  - Names and the `@Attribute(.unique)` constraint on each `id: UUID` come from SPEC §5.2 verbatim. Do not rename.
  - Enum raw types are `String` (codable across `WCSession` and JSON).
- **State of the world:** EPIC 01 has landed. The container opens with an empty schema; no models exist.

## Output Format

A single PR containing:

- [ ] Five `@Model` class shells, each with `@Attribute(.unique) var id: UUID` and a memberwise init that takes `id: UUID = UUID()`.
- [ ] `LoggedIngredientAmount` struct as `Codable, Sendable, Hashable` with the three fields from SPEC §5.2 (`ingredientID`, `ingredientName`, `totalMg`).
- [ ] Four enums (`MedicationKind`, `MedicationForm`, `DoseStatus`, `LogSource`) as `String, Codable, Sendable`.
- [ ] Schema updated in `PersistenceController` so the container actually migrates.
- [ ] One unit test (`SchemaSmokeTests.testContainerOpensWithModelGraph`) that constructs a `ModelContext`, inserts an `Ingredient(id:)`, and reads it back.

## Examples

`Shared/Models/Ingredient.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class Ingredient {
    @Attribute(.unique) public var id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}
```

`Shared/Models/Enums.swift`:

```swift
public enum MedicationKind: String, Codable, Sendable, CaseIterable {
    case maintenance, prn
}

public enum MedicationForm: String, Codable, Sendable, CaseIterable {
    case tablet, capsule, liquid, other
}

public enum DoseStatus: String, Codable, Sendable, CaseIterable {
    case taken, skipped, snoozed
}

public enum LogSource: String, Codable, Sendable, CaseIterable {
    case watch, iphone
}
```

Smoke test (abridged):

```swift
@MainActor
final class SchemaSmokeTests: XCTestCase {
    func testContainerOpensWithModelGraph() throws {
        let container = try ModelContainer(
            for: Schema([Ingredient.self, MedicationComponent.self, Medication.self,
                         ScheduledDose.self, DoseEvent.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let ingredient = Ingredient()
        context.insert(ingredient)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Ingredient>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, ingredient.id)
    }
}
```

## Constraints

**Scope fence:** Do not add real fields to any model beyond `id`. Do not add relationships. Do not add the `isHighRisk` computed property on `Medication`. Do not seed the ingredient library. Those are EPIC_02_ISSUE_02 and EPIC_02_ISSUE_03 respectively.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both targets must continue to build and the placeholder views from EPIC 01 must continue to render. The container now has tables for five model types but no UI surfaces it yet.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #2` and `Closes #EPIC_02_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-1-data-model`.
