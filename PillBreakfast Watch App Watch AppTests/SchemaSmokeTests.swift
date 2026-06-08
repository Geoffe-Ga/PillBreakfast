import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
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

    let ingredient = Ingredient(name: "Smoke Test")
    context.insert(ingredient)
    context.insert(MedicationComponent(dosagePerUnitMg: 1))
    context.insert(Medication(displayName: "Smoke Test", unitForm: .tablet, kind: .maintenance))
    context.insert(ScheduledDose(hour: 8, minute: 0, quantity: 1))
    context.insert(DoseEvent(medicationID: UUID(), takenAt: .now, quantity: 1, status: .taken, loggedOn: .watch))
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
