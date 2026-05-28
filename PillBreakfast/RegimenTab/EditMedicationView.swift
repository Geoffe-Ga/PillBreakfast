import os
import SwiftData
import SwiftUI

/// Edit form for an existing medication, reusing the shared form pre-filled from
/// the model. Pushes the updated regimen to the watch on save.
struct EditMedicationView: View {
  let medication: Medication
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var formState: MedicationFormState
  @State private var createdIngredientIDs: [UUID] = []

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  init(medication: Medication) {
    self.medication = medication
    _formState = State(initialValue: MedicationFormState(medication: medication))
  }

  var body: some View {
    MedicationFormView(formState: formState) { createdIngredientIDs.append($0) }
      .navigationTitle(medication.displayName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .disabled(!formState.isValid)
        }
      }
      // Covers backing out without saving: any inline-created ingredient that the
      // edit didn't end up referencing gets cleaned up.
      .onDisappear {
        InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
      }
  }

  private func save() {
    do {
      try formState.apply(to: medication, in: modelContext)
      try modelContext.save()
    } catch {
      EditMedicationView.logger.error("Failed to save medication edit: \(error.localizedDescription, privacy: .public)")
      // Revert any partial mutations to the existing medication.
      modelContext.rollback()
      return
    }
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    dismiss()
  }
}
