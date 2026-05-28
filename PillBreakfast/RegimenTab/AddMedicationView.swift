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
      modelContext.delete(medication) // roll back the partial insert
      InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
      return
    }
    InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    dismiss()
  }
}
