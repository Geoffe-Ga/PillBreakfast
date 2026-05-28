import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct ModelGraphTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func medicationRelationshipsRoundTrip() throws {
    let context = try makeInMemoryContext()

    let ingredient = Ingredient(name: "Lithium Carbonate", isHighRisk: true)
    let medication = Medication(displayName: "Lithobid 300mg", unitForm: .tablet, kind: .maintenance)
    medication.components = [MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 300)]
    medication.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    medication.doseEvents = [
      DoseEvent(takenAt: .now, quantity: 1, status: .taken, loggedOn: .watch),
    ]
    context.insert(medication)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Medication>())
    #expect(fetched.count == 1)
    let stored = try #require(fetched.first)
    #expect(stored.components.count == 1)
    #expect(stored.schedule.count == 1)
    #expect(stored.doseEvents.count == 1)
    // Inverse relationships are wired both ways.
    #expect(stored.components.first?.medication?.id == stored.id)
    #expect(stored.schedule.first?.medication?.id == stored.id)
    #expect(stored.doseEvents.first?.medication?.id == stored.id)
    #expect(stored.components.first?.ingredient?.id == ingredient.id)
  }

  @Test func deletingMedicationCascadesToOwnedChildren() throws {
    let context = try makeInMemoryContext()

    let medication = Medication(displayName: "Test Product", unitForm: .tablet, kind: .maintenance)
    medication.components = [MedicationComponent(ingredient: Ingredient(name: "X"), dosagePerUnitMg: 10)]
    medication.schedule = [ScheduledDose(hour: 9, minute: 30, quantity: 2)]
    medication.doseEvents = [
      DoseEvent(takenAt: .now, quantity: 1, status: .taken, loggedOn: .iphone),
    ]
    context.insert(medication)
    try context.save()

    context.delete(medication)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<Medication>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<MedicationComponent>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<ScheduledDose>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<DoseEvent>()).isEmpty)
    // Ingredients are shared library items, not owned by the medication.
    #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == 1)
  }

  @Test func medicationIsHighRiskWhenAnyIngredientIsHighRisk() throws {
    let context = try makeInMemoryContext()

    let lithium = Ingredient(name: "Lithium Carbonate", isHighRisk: true)
    let dye = Ingredient(name: "Inactive Dye", isHighRisk: false)
    let lithobid = Medication(displayName: "Lithobid 300mg", unitForm: .tablet, kind: .maintenance)
    lithobid.components = [
      MedicationComponent(ingredient: lithium, dosagePerUnitMg: 300),
      MedicationComponent(ingredient: dye, dosagePerUnitMg: 1),
    ]
    context.insert(lithobid)
    #expect(lithobid.isHighRisk)

    let vitaminD = Ingredient(name: "Cholecalciferol", isHighRisk: false)
    let vitaminMed = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    vitaminMed.components = [MedicationComponent(ingredient: vitaminD, dosagePerUnitMg: 2000)]
    context.insert(vitaminMed)
    #expect(!vitaminMed.isHighRisk)
  }
}
