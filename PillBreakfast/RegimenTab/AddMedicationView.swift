import os
import SwiftData
import SwiftUI

/// Sheet for adding a new maintenance medication. Saves the validated draft and
/// pushes the updated regimen to the watch.
struct AddMedicationView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: [SortDescriptor(\PillMeal.sortOrder), SortDescriptor(\PillMeal.createdAt)])
  private var pillMeals: [PillMeal]
  @State private var formState = MedicationFormState()
  @State private var createdIngredientIDs: [UUID] = []
  @State private var saveError: String?
  /// Non-nil once a saved med's first unassigned dose has been matched against
  /// existing meals — drives the inline "Add to Pill Meal?" prompt (§8.3).
  @State private var suggestion: PillMealSuggestion?
  /// The dose the prompt is offering to assign (the med's earliest unassigned
  /// dose). Held so the dialog actions know what to bind.
  @State private var pendingDose: ScheduledDose?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  var body: some View {
    NavigationStack {
      MedicationFormView(formState: formState) { createdIngredientIDs.append($0) }
        .navigationTitle("New Medication")
        .toolbarTitleDisplayMode(.inline)
        // Large-detent sheet so the form has room without dominating
        // the iPhone screen.
        .presentationDetents([.large])
        // Force exit through Cancel or Save — a drag-to-dismiss would
        // skip `cancel()` and leave any inline-created `Ingredient`s
        // orphaned in the store.
        .interactiveDismissDisabled(true)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { cancel() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
              .disabled(!formState.isValid)
          }
        }
        .alert(
          "Couldn't add medication",
          isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
          )
        ) {
          Button("OK", role: .cancel) { saveError = nil }
        } message: {
          Text(saveError ?? "")
        }
        .confirmationDialog(
          suggestionDialogTitle,
          isPresented: Binding(
            get: { suggestion != nil },
            // A dismissal that didn't go through a button (tap-outside) leaves
            // `suggestion` set — treat it as "Not now" and finish. The action
            // buttons nil `suggestion` themselves, so this guard skips the
            // double-handle.
            set: { if !$0, suggestion != nil { suggestion = nil; finish() } }
          ),
          titleVisibility: .visible
        ) {
          suggestionActions()
        } message: {
          if let message = suggestionDialogMessage {
            Text(message)
          }
        }
    }
  }

  @ViewBuilder
  private func suggestionActions() -> some View {
    switch suggestion {
    case let .single(meal)?:
      Button("Add to \(meal.name)") { assign(to: meal) }
    case let .multiple(meals)?:
      ForEach(meals) { meal in
        Button(meal.name) { assign(to: meal) }
      }
    case let .createNew(hour, minute)?:
      Button("Create new Pill Meal at \(PillMealSuggestion.timeLabel(hour: hour, minute: minute))") {
        createMealAndAssign(hour: hour, minute: minute)
      }
    case .some(.noMeals), nil:
      EmptyView()
    }
    Button("Not now", role: .cancel) { suggestion = nil; finish() }
  }

  private var suggestionDialogTitle: String {
    switch suggestion {
    case let .single(meal)?: "Add to \(meal.name)?"
    case .multiple?, .createNew?: "Add to a Pill Meal?"
    case .some(.noMeals), nil: ""
    }
  }

  private var suggestionDialogMessage: String? {
    guard let dose = pendingDose else { return nil }
    let time = PillMealSuggestion.timeLabel(hour: dose.hour, minute: dose.minute)
    switch suggestion {
    case .single?: return "This dose is at \(time)."
    case .createNew?: return "No existing meal is near \(time)."
    case .multiple?, .some(.noMeals), nil: return nil
    }
  }

  private func cancel() {
    InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
    dismiss()
  }

  private func save() {
    let medication = Medication(displayName: "", unitForm: formState.unitForm, kind: formState.kind)
    modelContext.insert(medication)
    do {
      try formState.apply(to: medication, in: modelContext)
      try modelContext.save()
    } catch {
      AddMedicationView.logger.error("Failed to add medication: \(error.localizedDescription, privacy: .public)")
      // Discard the partially-inserted medication (and any uncommitted inline
      // ingredients) so autosave can't flush a half-built graph.
      modelContext.rollback()
      InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
      // Generic copy matches `IngredientEditorView` / `RegimenListView`: raw
      // SwiftData error descriptions are technical ("operation could not be
      // completed") and not actionable; the OSLog above is the dev signal.
      saveError = "The medication couldn't be saved. Please try again."
      return
    }
    InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
    // No push here — every terminal path funnels through `finish()`, which
    // pushes exactly once. Pushing now would send an unassigned-dose regimen
    // that a later assignment immediately supersedes (mirrors the deferred-push
    // pattern in the HealthKit path).
    presentSuggestionOrDismiss(for: medication)
  }

  /// §8.3: after the med is saved, match its earliest *unassigned* dose against
  /// existing meals and surface the inline prompt. Doses the user already bound
  /// to a meal in the form are left alone. No prompt → finish straight away.
  private func presentSuggestionOrDismiss(for medication: Medication) {
    let unassigned = medication.schedule
      .filter { $0.pillMeal == nil }
      .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    guard let dose = unassigned.first else {
      finish()
      return
    }
    let result = PillMealSuggestion.propose(forDoseAt: (dose.hour, dose.minute), in: pillMeals)
    guard result != .noMeals else {
      finish()
      return
    }
    pendingDose = dose
    suggestion = result
  }

  private func assign(to meal: PillMeal) {
    // `pendingDose` is always set when `suggestion` is non-nil (see
    // `presentSuggestionOrDismiss`), so this guard is defensive — it can only
    // fire if state were cleared out from under the dialog. Finish cleanly.
    guard let dose = pendingDose else {
      suggestion = nil
      finish()
      return
    }
    dose.pillMeal = meal
    persistAssignment()
  }

  private func createMealAndAssign(hour: Int, minute: Int) {
    guard let dose = pendingDose else {
      suggestion = nil
      finish()
      return
    }
    let nextOrder = (pillMeals.map(\.sortOrder).max() ?? -1) + 1
    let meal = PillMeal(
      name: PillMealOnboardingService.suggestedName(forHour: hour, minute: minute),
      targetHour: hour,
      targetMinute: minute,
      sortOrder: nextOrder
    )
    modelContext.insert(meal)
    dose.pillMeal = meal
    persistAssignment()
  }

  /// Commits a dose→meal assignment (and any new meal). On failure the med
  /// itself is already saved, so we roll back just the assignment and keep the
  /// user on the form to retry rather than silently dropping it.
  private func persistAssignment() {
    do {
      try modelContext.save()
    } catch {
      AddMedicationView.logger.error("Failed to assign dose to meal: \(error.localizedDescription, privacy: .public)")
      // Safe to roll back wholesale: the medication was already committed by
      // `save()`, so the only uncommitted changes here are this assignment (and
      // any new meal). There's no other in-flight context state to lose.
      modelContext.rollback()
      suggestion = nil
      pendingDose = nil
      saveError = "The medication was added, but assigning it to a Pill Meal failed. You can set it from the Regimen tab."
      return
    }
    suggestion = nil
    finish()
  }

  /// Single exit point for the add flow: push the committed regimen to the
  /// watch once, then dismiss. Every terminal path (no prompt, assigned, or
  /// "Not now") routes through here so the watch sees one final state.
  private func finish() {
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    dismiss()
  }
}
