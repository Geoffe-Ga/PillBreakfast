import os
import SwiftData
import SwiftUI

/// Sheet for adding a new maintenance medication. Saves the validated draft and
/// pushes the updated regimen to the watch.
struct AddMedicationView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var formState = MedicationFormState()
  @State private var createdIngredientIDs: [UUID] = []
  @State private var saveError: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  var body: some View {
    NavigationStack {
      MedicationFormView(formState: formState) { createdIngredientIDs.append($0) }
        .navigationTitle("New Medication")
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
      // Sheet stays open so the user can fix the input and retry rather than
      // staring at an unchanged screen wondering whether Save did anything.
      saveError = "The medication couldn't be saved. Please try again."
      return
    }
    InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    dismiss()
  }
}
