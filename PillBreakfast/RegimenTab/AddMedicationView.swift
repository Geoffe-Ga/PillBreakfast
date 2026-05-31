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
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    dismiss()
  }
}
