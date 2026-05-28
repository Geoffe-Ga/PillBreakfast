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
    #expect(stored.count == 6)
  }

  @Test func reSeedingIsIdempotent() throws {
    let context = try makeInMemoryContext()
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == 6)
  }

  @Test func partialLibraryFillsOnlyTheMissingIngredients() throws {
    let context = try makeInMemoryContext()
    // Pre-insert two seeds by their canonical IDs, then seed the rest.
    for name in ["Aspirin", "Caffeine"] {
      context.insert(Ingredient(id: IngredientLibrarySeeder.stableUUID(for: name), name: name))
    }
    try context.save()

    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == 6)
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
}
