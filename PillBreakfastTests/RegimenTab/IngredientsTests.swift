import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct IngredientsTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  // MARK: - Deletion guards

  @Test func seededIngredientCannotBeDeleted() throws {
    let context = try makeContext()
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    let acetaminophen = try #require(
      context.fetch(FetchDescriptor<Ingredient>()).first { $0.name == "Acetaminophen" }
    )
    #expect(try IngredientDeletion.check(acetaminophen, in: context) == .seeded)
  }

  @Test func referencedUserIngredientCannotBeDeleted() throws {
    let context = try makeContext()
    let custom = Ingredient(name: "Custom Compound")
    context.insert(custom)
    let med = Medication(displayName: "Custom Med", unitForm: .tablet, kind: .prn)
    med.components = [MedicationComponent(ingredient: custom, dosagePerUnitMg: 100)]
    context.insert(med)
    try context.save()

    #expect(try IngredientDeletion.check(custom, in: context) == .referenced)
  }

  @Test func unreferencedUserIngredientCanBeDeleted() throws {
    let context = try makeContext()
    let custom = Ingredient(name: "Unused Compound")
    context.insert(custom)
    try context.save()

    #expect(try IngredientDeletion.check(custom, in: context) == .allowed)
  }

  // MARK: - High-risk sync

  @Test func highRiskToggleRoundTripsThroughSnapshot() throws {
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen", isHighRisk: false)
    context.insert(apap)
    try context.save()

    // Toggle high-risk on (as the editor would).
    apap.isHighRisk = true
    try context.save()

    // Build the snapshot, round-trip it through the wire, and apply to a fresh store.
    let snapshot = try RegimenSnapshot.from(context: context)
    let decoded = try JSONDecoder().decode(RegimenSnapshot.self, from: JSONEncoder().encode(snapshot))
    let fresh = try makeContext()
    try decoded.apply(to: fresh)

    let synced = try #require(fresh.fetch(FetchDescriptor<Ingredient>()).first { $0.id == apap.id })
    #expect(synced.isHighRisk)
  }
}
