import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct MedicationFormStateTests {
  private func validForm() -> MedicationFormState {
    let state = MedicationFormState()
    state.displayName = "Vitamin D"
    state.componentDraft = ComponentDraft(ingredientID: UUID(), dosagePerUnitMg: 2000)
    state.schedules = [ScheduleDraft(hour: 8, minute: 0, quantity: 1)]
    return state
  }

  @Test func emptyNameIsInvalid() {
    let state = validForm()
    state.displayName = "   "
    #expect(!state.isValid)
    #expect(state.validationErrors.contains("Name required."))
  }

  @Test func addPRNQuantityDedupesAndSorts() {
    let state = MedicationFormState()
    state.addPRNQuantity(2)
    state.addPRNQuantity(1)
    state.addPRNQuantity(2) // duplicate — ignored
    #expect(state.prnAvailableQuantities == [1, 2])
  }

  @Test func initFromMedicationPopulatesPRNQuantities() {
    let medication = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    medication.prnAvailableQuantities = [1, 2]
    let state = MedicationFormState(medication: medication)
    #expect(state.prnAvailableQuantities == [1, 2])
  }

  @Test func missingIngredientIsInvalid() {
    let state = validForm()
    state.componentDraft.ingredientID = nil
    #expect(!state.isValid)
  }

  @Test func zeroDosageIsInvalid() {
    let state = validForm()
    state.componentDraft.dosagePerUnitMg = 0
    #expect(!state.isValid)
    #expect(state.validationErrors.contains("Dosage per unit must be greater than zero."))
  }

  @Test func negativeDosageIsInvalid() {
    let state = validForm()
    state.componentDraft.dosagePerUnitMg = -1
    #expect(!state.isValid)
    #expect(state.validationErrors.contains("Dosage per unit must be greater than zero."))
  }

  @Test func maintenanceWithoutScheduleIsInvalid() {
    let state = validForm()
    state.kind = .maintenance
    state.schedules = []
    #expect(!state.isValid)
    #expect(state.validationErrors.contains("Add at least one scheduled time."))
  }

  @Test func prnWithoutScheduleIsValid() {
    let state = validForm()
    state.kind = .prn
    state.schedules = []
    #expect(state.isValid)
  }

  @Test func happyPathIsValid() {
    #expect(validForm().isValid)
  }

  @Test func applyWritesComponentAndScheduleFromDraft() throws {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let ingredient = Ingredient(name: "Cholecalciferol")
    context.insert(ingredient)

    let state = MedicationFormState()
    state.displayName = "Vitamin D"
    state.componentDraft = ComponentDraft(ingredientID: ingredient.id, dosagePerUnitMg: 2000)
    state.schedules = [ScheduleDraft(hour: 8, minute: 0, quantity: 1)]

    let medication = Medication(displayName: "", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try state.apply(to: medication, in: context)
    try context.save()

    #expect(medication.displayName == "Vitamin D")
    #expect(medication.components.count == 1)
    #expect(medication.components.first?.ingredient?.id == ingredient.id)
    #expect(medication.components.first?.dosagePerUnitMg == 2000)
    #expect(medication.schedule.count == 1)
    #expect(medication.schedule.first?.hour == 8)
  }

  @Test func initFromMedicationPrefillsTheForm() throws {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let ingredient = Ingredient(name: "Cholecalciferol")
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    medication.components = [MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 2000)]
    medication.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    context.insert(medication)
    try context.save()

    let state = MedicationFormState(medication: medication)
    #expect(state.displayName == "Vitamin D")
    #expect(state.unitForm == .capsule)
    #expect(state.componentDraft.ingredientID == ingredient.id)
    #expect(state.componentDraft.dosagePerUnitMg == 2000)
    #expect(state.schedules.count == 1)
    #expect(state.isValid)
  }

  @Test func applyThrowsWhenIngredientNotInStore() throws {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let state = MedicationFormState()
    state.displayName = "Mystery"
    state.componentDraft = ComponentDraft(ingredientID: UUID(), dosagePerUnitMg: 100)
    state.schedules = [ScheduleDraft(hour: 8, minute: 0, quantity: 1)]

    let medication = Medication(displayName: "", unitForm: .tablet, kind: .maintenance)
    context.insert(medication)
    #expect(throws: MedicationFormError.ingredientNotFound) {
      try state.apply(to: medication, in: context)
    }
  }
}
