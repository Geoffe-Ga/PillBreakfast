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

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  init(medication: Medication) {
    self.medication = medication
    _formState = State(initialValue: MedicationFormState(medication: medication))
  }

  var body: some View {
    MedicationFormView(formState: formState)
      .navigationTitle("Edit Medication")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .disabled(!formState.isValid)
        }
      }
  }

  private func save() {
    do {
      try formState.apply(to: medication, in: modelContext)
      try modelContext.save()
    } catch {
      EditMedicationView.logger.error("Failed to save medication edit: \(error.localizedDescription, privacy: .public)")
      return
    }
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    dismiss()
  }
}
