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
