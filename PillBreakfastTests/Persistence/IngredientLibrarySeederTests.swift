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
    let highRiskNames = [
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
      // `guard … Issue.record` rather than `try? #require` so a missing
      // ingredient and a wrong flag produce distinct failure messages.
      guard let spec = IngredientLibrarySeeder.seeds.first(where: { $0.name == name }) else {
        Issue.record("High-risk seed \"\(name)\" not found in library")
        continue
      }
      #expect(spec.isHighRisk == true, "\(name) must be isHighRisk")
    }
  }

  @Test func rxMaintenanceEntriesShipWithNilThresholds() {
    // Rx drugs ship name-only — inventing ceilings for narrow-TI prescription
    // drugs the user's prescriber owns is a medical-claim trap. Spot-check
    // several to pin the contract.
    let rxNames = ["Sertraline", "Lamotrigine", "Atorvastatin", "Metformin", "Lithium carbonate"]
    for name in rxNames {
      guard let spec = IngredientLibrarySeeder.seeds.first(where: { $0.name == name }) else {
        Issue.record("Rx seed \"\(name)\" not found in library")
        continue
      }
      #expect(spec.dailyCeilingMg == nil, "\(name) (Rx) must ship with dailyCeilingMg = nil")
      #expect(spec.minIntervalMinutes == nil, "\(name) (Rx) must ship with minIntervalMinutes = nil")
    }
  }

  @Test func otcAnalgesicsCarrySourcedThresholds() {
    // Spot-check the OTC analgesic block — every analgesic (including the
    // new Ketoprofen entry from #155) must keep its FDA-sourced thresholds.
    let expected: [(name: String, ceiling: Double, interval: Int)] = [
      ("Acetaminophen", 4000, 240),
      ("Ibuprofen", 1200, 360),
      ("Aspirin", 4000, 240),
      ("Naproxen", 660, 720),
      ("Ketoprofen", 75, 480),
    ]
    for case let (name, ceiling, interval) in expected {
      guard let spec = IngredientLibrarySeeder.seeds.first(where: { $0.name == name }) else {
        Issue.record("OTC analgesic \"\(name)\" not found in library")
        continue
      }
      #expect(spec.dailyCeilingMg == ceiling, "\(name) ceiling drift")
      #expect(spec.minIntervalMinutes == interval, "\(name) interval drift")
    }
  }

  @Test func otcAntihistaminesCarrySourcedThresholds() {
    // Pin the exact OTC antihistamine thresholds — a non-nil check alone
    // wouldn't catch a typo like a 10 → 100 mg ceiling. Both the original
    // Diphenhydramine and the new entries are spot-checked.
    let expected: [(name: String, ceiling: Double, interval: Int)] = [
      ("Diphenhydramine", 300, 240),
      ("Loratadine", 10, 1440),
      ("Cetirizine", 10, 1440),
      ("Fexofenadine", 180, 720),
      ("Levocetirizine", 5, 1440),
    ]
    for case let (name, ceiling, interval) in expected {
      guard let spec = IngredientLibrarySeeder.seeds.first(where: { $0.name == name }) else {
        Issue.record("OTC antihistamine \"\(name)\" not found in library")
        continue
      }
      #expect(spec.dailyCeilingMg == ceiling, "\(name) ceiling drift")
      #expect(spec.minIntervalMinutes == interval, "\(name) interval drift")
    }
  }

  @Test func diphenhydramineKeepsItsOriginalThresholds() {
    // Pin the exact values for the antihistamine that was in the original
    // six-entry library so the expansion didn't accidentally edit them.
    guard let spec = IngredientLibrarySeeder.seeds.first(where: { $0.name == "Diphenhydramine" }) else {
      Issue.record("Diphenhydramine not found in library")
      return
    }
    #expect(spec.dailyCeilingMg == 300)
    #expect(spec.minIntervalMinutes == 240)
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
      // Per #166 review: short codes like "B3" matter for autocomplete —
      // a user typing "B3" expects to find both forms.
      ("Vitamin B3 (Niacin)", "B3"),
      ("Vitamin B3 (Niacinamide)", "B3"),
    ]
    for case let (name, alias) in aliasContracts {
      guard let spec = IngredientLibrarySeeder.seeds.first(where: { $0.name == name }) else {
        Issue.record("Alias-contract seed \"\(name)\" not found in library")
        continue
      }
      #expect(spec.aliases.contains(alias), "\(name) should carry alias \"\(alias)\"")
    }
  }
}
