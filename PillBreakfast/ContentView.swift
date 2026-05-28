import os
import SwiftData
import SwiftUI

struct RootView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]

  var body: some View {
    NavigationStack {
      List {
        Section("Regimen") {
          ForEach(medications) { medication in
            MedicationNameRow(medication: medication, onCommit: saveAndPush)
          }
        }
      }
      .navigationTitle("PillBreakfast")
    }
  }

  private func saveAndPush() {
    do {
      try modelContext.save()
    } catch {
      RootView.logger.error("Failed to save regimen edit: \(error.localizedDescription, privacy: .public)")
      return
    }
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
  }

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")
}

/// One editable medication name. Editing mutates the model; committing (return key)
/// persists and pushes the fresh regimen to the watch.
private struct MedicationNameRow: View {
  @Bindable var medication: Medication
  let onCommit: () -> Void

  var body: some View {
    TextField("Medication name", text: $medication.displayName)
      .onSubmit(onCommit)
  }
}

#Preview {
  RootView()
    .modelContainer(for: Medication.self, inMemory: true)
}
