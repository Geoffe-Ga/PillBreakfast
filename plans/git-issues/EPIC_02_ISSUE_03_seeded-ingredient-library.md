## Role

You are a senior Swift engineer responsible for the first-launch experience of PillBreakfast. You understand SwiftData lightweight migrations, idempotent seeding, and how to avoid the duplicate-seed bug that plagues most first-launch flows.

## Goal

On first launch (on each device that has its own SwiftData store), seed a small library of common ingredients per SPEC §5.3 with **suggested** safety thresholds and a prominent disclaimer that these are user-defaults, not medical advice. Subsequent launches must be **idempotent** — no duplicate seeding. Geoff's specific meds (Lithium, Gabapentin) are *not* seeded; he enters those himself.

## Context

- **Parent epic:** #2
- **Predecessor issue(s):** #EPIC_02_ISSUE_02_NUMBER (full schema body must exist so `Ingredient` has `dailyCeilingMg`, `minIntervalMinutes`, `isHighRisk`).
- **SPEC section:** `plans/SPEC.md` §5.3 "Seeded ingredient library" (line 231): "Acetaminophen, Ibuprofen, Aspirin, Naproxen, Diphenhydramine, Caffeine." Plus the disclaimer language.
- **Files involved:**
  - `Shared/Persistence/IngredientLibrarySeeder.swift` (new) — the seeder.
  - `Shared/Persistence/PersistenceController.swift` — wire `IngredientLibrarySeeder.seedIfNeeded(context:)` into the controller's bootstrap path (after the container opens).
  - `PillBreakfastTests/Persistence/IngredientLibrarySeederTests.swift` — idempotency + content tests.
- **Prior decisions (locked):**
  - Seeds run on **both** devices, against each device's local SwiftData store. The watch is not seeded by sync; it does its own seed locally on first launch.
  - Idempotency key: `Ingredient.name` (case-insensitive). Avoid using `UUID` for dedup because we want a re-seed on a wiped install to use the same canonical IDs (so we don't fork the graph across devices). Use deterministic UUIDs derived from the ingredient name (e.g. `UUID(uuidString: stableUUIDString(for: "Acetaminophen"))`) — see Examples below.
  - **Suggested** thresholds, with a prominent disclaimer string available as `IngredientLibrarySeeder.disclaimer` so the iPhone Settings tab can display it later.
- **State of the world:** EPIC_02_ISSUE_02 has landed; the model graph is complete; no ingredients are seeded.

## Output Format

A single PR containing:

- [ ] `IngredientLibrarySeeder` with `static let seeds: [SeedSpec]` containing the six SPEC §5.3 ingredients with suggested ceilings and intervals (see Examples for proposed defaults; cite a publicly-available source like the FDA OTC monograph for each in the file's header comment).
- [ ] `seedIfNeeded(context:)` that inserts any missing ingredient (by deterministic UUID) and is a no-op for already-present ones.
- [ ] Disclaimer string exposed as `IngredientLibrarySeeder.disclaimer`.
- [ ] Wired into `PersistenceController` so seeding happens once per launch (the function is cheap; running it on every launch is fine because it's idempotent).
- [ ] Unit tests covering: first seed inserts 6 ingredients; re-running inserts 0; deterministic UUIDs are stable across runs; disclaimer is non-empty.

## Examples

`Shared/Persistence/IngredientLibrarySeeder.swift` (abridged):

```swift
public enum IngredientLibrarySeeder {
    public struct SeedSpec: Sendable {
        public let name: String
        public let aliases: [String]
        public let isHighRisk: Bool
        public let dailyCeilingMg: Double?
        public let minIntervalMinutes: Int?
    }

    public static let disclaimer: String = """
    The suggested thresholds below are starting points only. They are NOT medical
    advice. Confirm every ceiling and interval with your prescriber before relying
    on them. PillBreakfast warns, it does not lock you out.
    """

    public static let seeds: [SeedSpec] = [
        SeedSpec(name: "Acetaminophen", aliases: ["Paracetamol", "APAP"],
                 isHighRisk: false, dailyCeilingMg: 4000, minIntervalMinutes: 240),
        SeedSpec(name: "Ibuprofen", aliases: [],
                 isHighRisk: false, dailyCeilingMg: 1200, minIntervalMinutes: 360),
        SeedSpec(name: "Aspirin", aliases: ["ASA"],
                 isHighRisk: false, dailyCeilingMg: 4000, minIntervalMinutes: 240),
        SeedSpec(name: "Naproxen", aliases: [],
                 isHighRisk: false, dailyCeilingMg: 660, minIntervalMinutes: 720),
        SeedSpec(name: "Diphenhydramine", aliases: [],
                 isHighRisk: false, dailyCeilingMg: 300, minIntervalMinutes: 240),
        SeedSpec(name: "Caffeine", aliases: [],
                 isHighRisk: false, dailyCeilingMg: 400, minIntervalMinutes: nil),
    ]

    @MainActor
    public static func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Ingredient>()).map { $0.id }
        let existingSet = Set(existing)
        for spec in seeds {
            let id = stableUUID(for: spec.name)
            guard !existingSet.contains(id) else { continue }
            let ingredient = Ingredient(
                id: id,
                name: spec.name,
                aliases: spec.aliases,
                isHighRisk: spec.isHighRisk,
                dailyCeilingMg: spec.dailyCeilingMg,
                minIntervalMinutes: spec.minIntervalMinutes
            )
            context.insert(ingredient)
        }
        try context.save()
    }

    // Deterministic UUIDv5-style derivation from a namespace + the ingredient name.
    // Implementation in Examples below. Do not regenerate at random.
    static func stableUUID(for name: String) -> UUID { /* ... */ }
}
```

Idempotency test:

```swift
func testSeedingIsIdempotent() throws {
    let context = try makeInMemoryContext()
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Ingredient>()).count, 6)
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Ingredient>()).count, 6)
}
```

## Constraints

**Scope fence:** Do not seed `Medication`s. Do not surface the disclaimer in any UI — that's EPIC 05's Ingredients screen. Do not pre-fill Lithium or Gabapentin. Geoff's specific meds are not in the public ingredient library.

**Thresholds are suggestions.** Cite a source for each (FDA OTC monograph, NIH MedlinePlus, etc.) in the file's header so a future reviewer can audit. **Do not** present these as "safe limits" anywhere in user-facing copy. They are *defaults to start the conversation with the prescriber*.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No UI changes. The placeholder views from EPIC 01 still render. Launching the app on a fresh simulator now inserts 6 `Ingredient` rows into the local SwiftData store on each device.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #2` and `Closes #EPIC_02_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-1-data-model`.
