import Foundation
import os
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
  /// PRN "take N at a time" options. Edited by `PRNFormSection`; persisting it is
  /// deliberately deferred to EPIC_05_ISSUE_06 (PRN save semantics), so `apply`
  /// doesn't write it yet — this skeleton only ships the field + editor.
  var prnAvailableQuantities: [Int] = []

  init() {}

  /// Pre-fills the form from an existing medication for editing.
  init(medication: Medication) {
    self.displayName = medication.displayName
    self.unitForm = medication.unitForm
    self.kind = medication.kind
    self.prnAvailableQuantities = medication.prnAvailableQuantities
    // SPEC §5: maintenance products are single-component, so the first component is the one.
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

  /// Adds a PRN "take N" option, de-duplicated and kept sorted. No-op if already
  /// present — callers should disable their add affordance in that case.
  func addPRNQuantity(_ quantity: Int) {
    guard !prnAvailableQuantities.contains(quantity) else { return }
    prnAvailableQuantities.append(quantity)
    prnAvailableQuantities.sort()
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
    // TODO(EPIC_05_ISSUE_06): persist prnAvailableQuantities (and multi-ingredient
    // combo components) here. The skeleton edits the field in form state but does
    // not yet write it back to the model.

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

/// Cleans up ingredients created inline via the "New Ingredient…" sub-form that
/// no medication ended up referencing — e.g. the user added one, then cancelled.
/// Because the main context autosaves, an orphan would otherwise be flushed.
@MainActor
enum InlineIngredientCleanup {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  static func discardUnreferenced(_ createdIDs: [UUID], in context: ModelContext) {
    guard !createdIDs.isEmpty else { return }
    do {
      let referenced = try Set(
        context.fetch(FetchDescriptor<MedicationComponent>()).compactMap { $0.ingredient?.id }
      )
      var deletedAny = false
      for id in createdIDs where !referenced.contains(id) {
        let descriptor = FetchDescriptor<Ingredient>(predicate: #Predicate { $0.id == id })
        if let ingredient = try context.fetch(descriptor).first {
          context.delete(ingredient)
          deletedAny = true
        }
      }
      if deletedAny {
        try context.save()
      }
    } catch {
      logger.error("Failed to clean up inline-created ingredients: \(error.localizedDescription, privacy: .public)")
    }
  }
}
