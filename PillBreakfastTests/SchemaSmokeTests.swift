import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct SchemaSmokeTests {
  @Test func containerOpensWithModelGraph() throws {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)

    let ingredient = Ingredient()
    context.insert(ingredient)
    context.insert(MedicationComponent())
    context.insert(Medication())
    context.insert(ScheduledDose())
    context.insert(DoseEvent())
    try context.save()

    // Fetch every model type so a missing entry in PersistenceController.schema
    // surfaces here rather than silently dropping a table.
    #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<MedicationComponent>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<Medication>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<ScheduledDose>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<DoseEvent>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<Ingredient>()).first?.id == ingredient.id)
  }
}
