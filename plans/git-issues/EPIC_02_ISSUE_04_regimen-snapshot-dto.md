## Role

You are a senior Swift engineer designing the wire format between PillBreakfast's iPhone and watch targets. You understand why passing `@Model` reference types across an actor boundary or over `WCSession` is a footgun, and why a separate immutable DTO is the right answer.

## Goal

Add a `RegimenSnapshot: Codable, Sendable` DTO in `Shared/Sync/` that represents a complete pushable regimen (medications + their components + their schedules + the ingredient library). Add round-trip Codable tests proving the DTO encodes and decodes losslessly. Add converters: `RegimenSnapshot.from(context:)` on iPhone and `RegimenSnapshot.apply(to:)` on watch.

## Context

- **Parent epic:** #2
- **Predecessor issue(s):** #EPIC_02_ISSUE_03_NUMBER (seeded library exists; the DTO encodes it).
- **SPEC section:** `plans/SPEC.md` §4 (Sync row), §5 (Data Model — the DTO mirrors the schema), §10 Phase 1 (lines 409-419, the `updateApplicationContext` round-trip).
- **Files involved (new):**
  - `Shared/Sync/RegimenSnapshot.swift` — the DTO graph.
  - `PillBreakfastTests/Sync/RegimenSnapshotTests.swift` — Codable round-trip + the SwiftData converters.
- **Prior decisions (locked):**
  - **Never serialize `@Model` classes directly.** They are reference types with relationship semantics that don't round-trip through `JSONEncoder`. Use value-type DTOs.
  - The DTO is one-way: iPhone -> watch. `DoseEvent`s flow watch -> iPhone via a separate channel (`WCSession.transferFile`), which EPIC 03 implements.
  - The DTO encodes `Ingredient` too (with thresholds), so the watch can render PRN ingredient totals without re-deriving thresholds from a hard-coded library.
- **State of the world:** The schema is complete and seeded. There is no sync code beyond the activation handshake from EPIC 01.

## Output Format

A single PR containing:

- [ ] `RegimenSnapshot` struct with three top-level arrays: `ingredients: [IngredientDTO]`, `medications: [MedicationDTO]` (which embeds `[ComponentDTO]` and `[ScheduledDoseDTO]`), and a `schemaVersion: Int` for future migration safety.
- [ ] DTO types are all `struct`, `Codable`, `Sendable`, `Hashable`. No reference semantics.
- [ ] `RegimenSnapshot.from(context: ModelContext)` reads the current SwiftData store and produces a snapshot.
- [ ] `RegimenSnapshot.apply(to: ModelContext)` writes a snapshot into a target SwiftData store with **upsert** semantics keyed on `id`. Records present in the store but absent from the snapshot are **archived**, not deleted, to be safe (`Medication.isArchived = true`).
- [ ] Codable round-trip test using a known fixture.
- [ ] Apply test: build a snapshot from one context, apply it to a second context, assert the two stores have equivalent contents.

## Examples

```swift
public struct RegimenSnapshot: Codable, Sendable, Hashable {
    public static let currentSchemaVersion: Int = 1
    public var schemaVersion: Int = Self.currentSchemaVersion
    public var ingredients: [IngredientDTO]
    public var medications: [MedicationDTO]
}

public struct IngredientDTO: Codable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let aliases: [String]
    public let isHighRisk: Bool
    public let dailyCeilingMg: Double?
    public let minIntervalMinutes: Int?
}

public struct MedicationDTO: Codable, Sendable, Hashable {
    public let id: UUID
    public let displayName: String
    public let fullName: String?
    public let unitForm: MedicationForm
    public let kind: MedicationKind
    public let colorHex: String?
    public let notes: String?
    public let isArchived: Bool
    public let createdAt: Date
    public let healthKitConceptID: String?
    public let prnAvailableQuantities: [Int]
    public let components: [ComponentDTO]
    public let schedule: [ScheduledDoseDTO]
}
```

Round-trip test:

```swift
func testSnapshotCodableRoundTrip() throws {
    let snapshot = RegimenSnapshot.fixture()
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(RegimenSnapshot.self, from: data)
    XCTAssertEqual(snapshot, decoded)
}
```

Apply test:

```swift
func testApplySnapshotUpsertsAndArchivesMissing() throws {
    let srcContext = try makeInMemoryContext()
    let dstContext = try makeInMemoryContext()
    let preexistingOnDst = Medication(id: UUID(), displayName: "Old Lithium", ...)
    dstContext.insert(preexistingOnDst)
    try dstContext.save()

    let snapshot = RegimenSnapshot.from(context: srcContext)  // contains a new "Lithobid" med
    try snapshot.apply(to: dstContext)
    try dstContext.save()

    let meds = try dstContext.fetch(FetchDescriptor<Medication>())
    XCTAssertTrue(meds.contains { $0.displayName == "Lithobid" })
    XCTAssertTrue(meds.first { $0.id == preexistingOnDst.id }?.isArchived == true)
}
```

## Constraints

**Scope fence:** Do not actually send the snapshot over `WCSession` yet — that's EPIC_02_ISSUE_05. Do not implement reverse sync for `DoseEvent`s — that's EPIC 03. Do not use this DTO for the eventual HealthKit import path — EPIC 07 has its own draft type.

**Reference-type leak protection:** Never expose a SwiftData `@Model` from a `Sendable` API. If you need to surface a model in a snapshot-creation API, take a `ModelContext` (which is itself main-actor-bound) and return value-typed DTOs.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No UI changes. The DTO + converters are pure data plumbing; both targets still render the placeholder views.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #2` and `Closes #EPIC_02_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-1-data-model`, `concurrency`.
