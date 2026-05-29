import os
import SwiftData
import SwiftUI

/// Grouped regimen list (Maintenance / PRN) with add, edit, and swipe-to-archive.
/// Editing pushes the updated regimen to the watch via `WatchConnectivityCoordinator`.
struct RegimenListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]
  @State private var showingAdd = false
  @State private var showingHealthKitImport = false
  @State private var archiveError: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  private var maintenance: [Medication] {
    medications.filter { $0.kind == .maintenance }
  }

  private var prn: [Medication] {
    medications.filter { $0.kind == .prn }
  }

  var body: some View {
    List {
      if medications.isEmpty {
        ContentUnavailableView("No medications yet", systemImage: "pills")
      } else {
        section("Maintenance", medications: maintenance)
        section("PRN", medications: prn)
      }
    }
    .scrollContentBackground(.hidden)
    .glassBackground()
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showingAdd = true
        } label: {
          Label("Add medication", systemImage: "plus")
        }
      }
      ToolbarItem(placement: .secondaryAction) {
        Button {
          showingHealthKitImport = true
        } label: {
          Label("Import from Apple Health", systemImage: "heart.text.square")
        }
      }
    }
    .sheet(isPresented: $showingAdd) {
      AddMedicationView()
    }
    .sheet(isPresented: $showingHealthKitImport) {
      HealthKitImportSheet()
    }
    .alert(
      "Couldn't archive medication",
      isPresented: Binding(get: { archiveError != nil }, set: { if !$0 { archiveError = nil } })
    ) {
      Button("OK", role: .cancel) { archiveError = nil }
    } message: {
      Text(archiveError ?? "")
    }
  }

  @ViewBuilder
  private func section(_ title: String, medications: [Medication]) -> some View {
    if !medications.isEmpty {
      Section(title) {
        ForEach(medications) { medication in
          NavigationLink {
            EditMedicationView(medication: medication)
          } label: {
            Text(medication.displayName)
          }
          .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
              archive(medication)
            } label: {
              Label("Archive", systemImage: "archivebox")
            }
          }
        }
      }
    }
  }

  private func archive(_ medication: Medication) {
    medication.isArchived = true
    do {
      try modelContext.save()
    } catch {
      RegimenListView.logger.error("Failed to archive medication: \(error.localizedDescription, privacy: .public)")
      modelContext.rollback()
      archiveError = "The change couldn't be saved. Please try again."
      return
    }
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
  }
}

#Preview {
  NavigationStack {
    RegimenListView()
  }
  .modelContainer(for: Medication.self, inMemory: true)
}
