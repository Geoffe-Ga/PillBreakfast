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

/// One editable medication name. Editing mutates the model; the change is persisted
/// and pushed to the watch on Return *and* on focus loss, so navigating away without
/// pressing Return can't leave the watch silently diverged from the iPhone.
private struct MedicationNameRow: View {
  @Bindable var medication: Medication
  let onCommit: () -> Void
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("Medication name", text: $medication.displayName)
      .focused($isFocused)
      // Return just resigns focus; the focus-loss handler below is the single
      // commit point, so Return and navigate-away both push exactly once.
      .onSubmit { isFocused = false }
      .onChange(of: isFocused) { _, focused in
        if !focused { onCommit() }
      }
  }
}

#Preview {
  RootView()
    .modelContainer(for: Medication.self, inMemory: true)
}
