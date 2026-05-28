import Foundation
import SwiftData

/// Editable draft of a medication's single ingredient component.
struct ComponentDraft: Hashable {
  var ingredientID: UUID?
  var dosagePerUnitMg: Double = 0

  static let empty = ComponentDraft()
}

/// Editable draft of one scheduled dose.
struct ScheduleDraft: Identifiable, Hashable {
  let id = UUID()
  var hour = 8
  var minute = 0
  var quantity = 1
}

/// `@Observable` form state backing the add/edit medication form. Not a SwiftData
/// model — it captures user input and validates it; `apply(to:in:)` writes the
/// validated draft into a `Medication`.
@MainActor
@Observable
final class MedicationFormState {
  var displayName = ""
  var unitForm: MedicationForm = .tablet
  var kind: MedicationKind = .maintenance
  var componentDraft: ComponentDraft = .empty
  var schedules: [ScheduleDraft] = []

  init() {}

  /// Pre-fills the form from an existing medication for editing.
  init(medication: Medication) {
    self.displayName = medication.displayName
    self.unitForm = medication.unitForm
    self.kind = medication.kind
    if let component = medication.components.first {
      self.componentDraft = ComponentDraft(
        ingredientID: component.ingredient?.id,
        dosagePerUnitMg: component.dosagePerUnitMg
      )
    }
    self.schedules = medication.schedule
      .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
      .map { ScheduleDraft(hour: $0.hour, minute: $0.minute, quantity: $0.quantity) }
  }

  var validationErrors: [String] {
    var errors: [String] = []
    if displayName.trimmingCharacters(in: .whitespaces).isEmpty {
      errors.append("Name required.")
    }
    if componentDraft.ingredientID == nil {
      errors.append("Select an ingredient.")
    }
    if componentDraft.dosagePerUnitMg <= 0 {
      errors.append("Dosage per unit must be greater than zero.")
    }
    if kind == .maintenance, schedules.isEmpty {
      errors.append("Add at least one scheduled time.")
    }
    return errors
  }

  var isValid: Bool {
    validationErrors.isEmpty
  }

  /// Writes the validated draft into `medication`, rebuilding its component and
  /// schedule. Throws if the chosen ingredient can't be resolved in the store.
  func apply(to medication: Medication, in context: ModelContext) throws {
    guard
      let ingredientID = componentDraft.ingredientID,
      let ingredient = try context.fetch(
        FetchDescriptor<Ingredient>(predicate: #Predicate { $0.id == ingredientID })
      ).first
    else {
      throw MedicationFormError.ingredientNotFound
    }

    medication.displayName = displayName.trimmingCharacters(in: .whitespaces)
    medication.unitForm = unitForm
    medication.kind = kind

    for old in medication.components {
      context.delete(old)
    }
    medication.components = [
      MedicationComponent(ingredient: ingredient, dosagePerUnitMg: componentDraft.dosagePerUnitMg),
    ]

    for old in medication.schedule {
      context.delete(old)
    }
    medication.schedule = schedules.map {
      ScheduledDose(hour: $0.hour, minute: $0.minute, quantity: $0.quantity)
    }
  }
}

enum MedicationFormError: Error, Equatable {
  case ingredientNotFound
}
