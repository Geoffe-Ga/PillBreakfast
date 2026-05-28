import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct InlineIngredientCleanupTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func deletesAnUnreferencedCreatedIngredient() throws {
    let context = try makeInMemoryContext()
    let orphan = Ingredient(name: "Orphan")
    context.insert(orphan)
    try context.save()

    InlineIngredientCleanup.discardUnreferenced([orphan.id], in: context)

    #expect(try context.fetch(FetchDescriptor<Ingredient>()).isEmpty)
  }

  @Test func keepsACreatedIngredientThatIsReferenced() throws {
    let context = try makeInMemoryContext()
    let used = Ingredient(name: "Cholecalciferol")
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    medication.components = [MedicationComponent(ingredient: used, dosagePerUnitMg: 2000)]
    context.insert(medication)
    try context.save()

    InlineIngredientCleanup.discardUnreferenced([used.id], in: context)

    #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == 1)
  }

  @Test func emptyInputIsANoOp() throws {
    let context = try makeInMemoryContext()
    context.insert(Ingredient(name: "Keep me"))
    try context.save()

    InlineIngredientCleanup.discardUnreferenced([], in: context)

    #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == 1)
  }
}
