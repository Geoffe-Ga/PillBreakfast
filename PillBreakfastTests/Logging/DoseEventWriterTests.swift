import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct DoseEventWriterTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func singleIngredientSnapshotScalesByQuantity() throws {
    let context = try makeInMemoryContext()
    let cholecalciferol = Ingredient(name: "Cholecalciferol")
    let vitaminD = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    vitaminD.components = [MedicationComponent(ingredient: cholecalciferol, dosagePerUnitMg: 2000)]
    context.insert(vitaminD)
    try context.save()

    let event = try DoseEventWriter.writeDoseEvent(
      for: vitaminD, scheduledFor: nil, quantity: 1, status: .taken, loggedOn: .watch, at: .now, in: context
    )

    #expect(event.status == .taken)
    #expect(event.loggedOn == .watch)
    #expect(event.ingredientAmounts.count == 1)
    #expect(event.ingredientAmounts.first?.ingredientName == "Cholecalciferol")
    #expect(event.ingredientAmounts.first?.totalMg == 2000)
    #expect(try context.fetch(FetchDescriptor<DoseEvent>()).count == 1)
  }

  @Test func comboProductSnapshotsEveryIngredientScaled() throws {
    let context = try makeInMemoryContext()
    let acetaminophen = Ingredient(name: "Acetaminophen")
    let aspirin = Ingredient(name: "Aspirin")
    let caffeine = Ingredient(name: "Caffeine")
    let excedrin = Medication(displayName: "Excedrin Extra Strength", unitForm: .tablet, kind: .prn)
    excedrin.components = [
      MedicationComponent(ingredient: acetaminophen, dosagePerUnitMg: 250),
      MedicationComponent(ingredient: aspirin, dosagePerUnitMg: 250),
      MedicationComponent(ingredient: caffeine, dosagePerUnitMg: 65),
    ]
    context.insert(excedrin)
    try context.save()

    let event = try DoseEventWriter.writeDoseEvent(
      for: excedrin, scheduledFor: nil, quantity: 2, status: .taken, loggedOn: .watch, at: .now, in: context
    )

    #expect(event.ingredientAmounts.count == 3)
    #expect(event.ingredientAmounts.first { $0.ingredientName == "Acetaminophen" }?.totalMg == 500)
    #expect(event.ingredientAmounts.first { $0.ingredientName == "Aspirin" }?.totalMg == 500)
    #expect(event.ingredientAmounts.first { $0.ingredientName == "Caffeine" }?.totalMg == 130)
  }

  @Test func snapshotIsFrozenAgainstLaterComponentEdits() throws {
    let context = try makeInMemoryContext()
    let ingredient = Ingredient(name: "Acetaminophen")
    let component = MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 500)
    let tylenol = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    tylenol.components = [component]
    context.insert(tylenol)
    try context.save()

    let event = try DoseEventWriter.writeDoseEvent(
      for: tylenol, scheduledFor: nil, quantity: 1, status: .taken, loggedOn: .watch, at: .now, in: context
    )

    // Editing the product afterwards must not rewrite the logged snapshot.
    component.dosagePerUnitMg = 650
    try context.save()

    #expect(event.ingredientAmounts.first?.totalMg == 500)
  }

  @Test func componentWithoutIngredientIsDroppedButRestSnapshot() throws {
    let context = try makeInMemoryContext()
    let valid = Ingredient(name: "Acetaminophen")
    let combo = Medication(displayName: "Broken Combo", unitForm: .tablet, kind: .prn)
    combo.components = [
      MedicationComponent(ingredient: valid, dosagePerUnitMg: 250),
      MedicationComponent(dosagePerUnitMg: 65), // no ingredient — store-integrity violation
    ]
    context.insert(combo)
    try context.save()

    let event = try DoseEventWriter.writeDoseEvent(
      for: combo, scheduledFor: nil, quantity: 1, status: .taken, loggedOn: .watch, at: .now, in: context
    )

    // The broken component is dropped; the valid one survives intact.
    #expect(event.ingredientAmounts.count == 1)
    #expect(event.ingredientAmounts.first?.ingredientName == "Acetaminophen")
    #expect(event.ingredientAmounts.first?.totalMg == 250)
  }

  @Test func skipWritesSkippedStatus() throws {
    let context = try makeInMemoryContext()
    let ingredient = Ingredient(name: "Cholecalciferol")
    let vitaminD = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    vitaminD.components = [MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 2000)]
    context.insert(vitaminD)
    try context.save()

    let event = try DoseEventWriter.writeDoseEvent(
      for: vitaminD, scheduledFor: .now, quantity: 1, status: .skipped, loggedOn: .watch, at: .now, in: context
    )
    #expect(event.status == .skipped)
    // The ingredient snapshot is written even on a skip (schema expectation).
    #expect(event.ingredientAmounts.count == 1)
  }
}
