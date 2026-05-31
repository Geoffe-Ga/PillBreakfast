import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct IngredientLibrarySeederTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func firstSeedInsertsTheFullLibrary() throws {
    let context = try makeInMemoryContext()
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    let stored = try context.fetch(FetchDescriptor<Ingredient>())
    #expect(stored.count == IngredientLibrarySeeder.seeds.count)
  }

  @Test func reSeedingIsIdempotent() throws {
    let context = try makeInMemoryContext()
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == IngredientLibrarySeeder.seeds.count)
  }

  @Test func partialLibraryFillsOnlyTheMissingIngredients() throws {
    let context = try makeInMemoryContext()
    // Pre-insert two seeds by their canonical IDs, then seed the rest.
    for name in ["Aspirin", "Caffeine"] {
      context.insert(Ingredient(id: IngredientLibrarySeeder.stableUUID(for: name), name: name))
    }
    try context.save()

    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == IngredientLibrarySeeder.seeds.count)
  }

  @Test func canonicalUUIDForAcetaminophenNeverChanges() throws {
    // Pins the v5 derivation: a broken namespace/encoding would change this.
    let expected = try #require(UUID(uuidString: "832901A0-2C5A-5216-A85C-9D7544BB4928"))
    #expect(IngredientLibrarySeeder.stableUUID(for: "Acetaminophen") == expected)
  }

  @Test func deterministicUUIDsAreStableAndCaseInsensitive() {
    #expect(
      IngredientLibrarySeeder.stableUUID(for: "Acetaminophen")
        == IngredientLibrarySeeder.stableUUID(for: "Acetaminophen")
    )
    #expect(
      IngredientLibrarySeeder.stableUUID(for: "Acetaminophen")
        == IngredientLibrarySeeder.stableUUID(for: "acetaminophen")
    )
    #expect(
      IngredientLibrarySeeder.stableUUID(for: "Acetaminophen")
        != IngredientLibrarySeeder.stableUUID(for: "Ibuprofen")
    )
  }

  @Test func seededIngredientsCarrySuggestedThresholds() throws {
    let context = try makeInMemoryContext()
    try IngredientLibrarySeeder.seedIfNeeded(context: context)

    let acetaminophenID = IngredientLibrarySeeder.stableUUID(for: "Acetaminophen")
    let descriptor = FetchDescriptor<Ingredient>(
      predicate: #Predicate { $0.id == acetaminophenID }
    )
    let acetaminophen = try #require(try context.fetch(descriptor).first)
    #expect(acetaminophen.name == "Acetaminophen")
    #expect(acetaminophen.dailyCeilingMg == 4000)
    #expect(acetaminophen.minIntervalMinutes == 240)
    #expect(acetaminophen.aliases.contains("Paracetamol"))
  }

  @Test func disclaimerIsNonEmpty() {
    #expect(!IngredientLibrarySeeder.disclaimer.isEmpty)
  }

  // MARK: - #155 library expansion invariants

  @Test func libraryIsExpandedBeyondTheOriginalSix() {
    // Sanity floor — the expansion is at least an order of magnitude larger
    // than the original seed set. Catch a regression that accidentally drops
    // a whole category block.
    #expect(IngredientLibrarySeeder.seeds.count >= 100)
  }

  @Test func seedNamesAreUnique() {
    // `stableUUID` derives from `name.lowercased()`, so two seeds sharing a
    // name produce the same canonical ID and the second one silently never
    // inserts. Names also have to be globally unique on a case-insensitive
    // basis so aliases like "Naproxen sodium" can't accidentally collide
    // with a primary name elsewhere in the library.
    let names = IngredientLibrarySeeder.seeds.map { $0.name.lowercased() }
    #expect(names.count == Set(names).count, "Seed names must be unique (case-insensitive)")
  }

  @Test func seedStableUUIDsAreUnique() {
    // Belt-and-suspenders for the name-uniqueness check above: confirm the
    // SHA-1 derivation didn't accidentally collide across all names.
    let ids = IngredientLibrarySeeder.seeds.map { IngredientLibrarySeeder.stableUUID(for: $0.name) }
    #expect(ids.count == Set(ids).count, "Seed canonical UUIDs must be collision-free")
  }

  @Test func narrowTherapeuticIndexRxIsFlaggedHighRisk() {
    // The SPEC reserves the press-and-hold confirm gesture for high-risk
    // meds. The named narrow-TI Rx drugs below must all be flagged so a
    // future regression that drops the flag is caught.
    let highRiskNames: Set = [
      "Lithium carbonate",
      "Lamotrigine",
      "Valproate",
      "Carbamazepine",
      "Levothyroxine",
      "Methotrexate",
      "Warfarin",
      "Digoxin",
    ]
    for name in highRiskNames {
      let spec = try? #require(IngredientLibrarySeeder.seeds.first { $0.name == name })
      #expect(spec?.isHighRisk == true, "\(name) must be isHighRisk")
    }
  }

  @Test func rxMaintenanceEntriesShipWithNilThresholds() {
    // Rx drugs ship name-only — inventing ceilings for narrow-TI prescription
    // drugs the user's prescriber owns is a medical-claim trap. Spot-check
    // several to pin the contract.
    let rxNames = ["Sertraline", "Lamotrigine", "Atorvastatin", "Metformin", "Lithium carbonate"]
    for name in rxNames {
      let spec = try? #require(IngredientLibrarySeeder.seeds.first { $0.name == name })
      #expect(spec?.dailyCeilingMg == nil, "\(name) (Rx) must ship with dailyCeilingMg = nil")
      #expect(spec?.minIntervalMinutes == nil, "\(name) (Rx) must ship with minIntervalMinutes = nil")
    }
  }

  @Test func otcAnalgesicsCarrySourcedThresholds() {
    // Spot-check the OTC analgesic block — all four classic NSAIDs/analgesics
    // must keep their FDA-sourced thresholds.
    let expected: [(name: String, ceiling: Double, interval: Int)] = [
      ("Acetaminophen", 4000, 240),
      ("Ibuprofen", 1200, 360),
      ("Aspirin", 4000, 240),
      ("Naproxen", 660, 720),
    ]
    for case let (name, ceiling, interval) in expected {
      let spec = try? #require(IngredientLibrarySeeder.seeds.first { $0.name == name })
      #expect(spec?.dailyCeilingMg == ceiling, "\(name) ceiling drift")
      #expect(spec?.minIntervalMinutes == interval, "\(name) interval drift")
    }
  }

  @Test func newOTCAntihistaminesCarrySourcedThresholds() {
    // The expansion adds several OTC antihistamines — they each ship with
    // FDA-monograph / per-product-labeling thresholds so the safety check
    // can fire on real overdoses.
    let antihistamines = ["Loratadine", "Cetirizine", "Fexofenadine", "Levocetirizine"]
    for name in antihistamines {
      let spec = try? #require(IngredientLibrarySeeder.seeds.first { $0.name == name })
      #expect(spec?.dailyCeilingMg != nil, "\(name) (OTC) must ship with a ceiling")
      #expect(spec?.minIntervalMinutes != nil, "\(name) (OTC) must ship with an interval")
    }
  }

  @Test func aliasesAreNonEmptyOnSeedsWithCommonSynonyms() {
    // Autocomplete leans on aliases. A few canonical examples must keep
    // their synonyms so search by "APAP" / "ASA" / brand name still surfaces
    // the right ingredient.
    let aliasContracts: [(name: String, requiredAlias: String)] = [
      ("Acetaminophen", "APAP"),
      ("Aspirin", "ASA"),
      ("Lithium carbonate", "Lithium"),
      ("Vitamin B9", "Folic acid"),
      ("Vitamin C", "Ascorbic acid"),
    ]
    for case let (name, alias) in aliasContracts {
      let spec = try? #require(IngredientLibrarySeeder.seeds.first { $0.name == name })
      #expect(spec?.aliases.contains(alias) == true, "\(name) should carry alias \"\(alias)\"")
    }
  }
}
