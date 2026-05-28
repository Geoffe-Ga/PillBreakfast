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
}
