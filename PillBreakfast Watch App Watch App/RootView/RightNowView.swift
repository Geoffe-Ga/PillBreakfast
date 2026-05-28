import os
import SwiftData
import SwiftUI

/// Watch root. Routes to the tap-through queue when doses are pending, else
/// "All caught up". The pending set comes from `PendingQueueSelector`, a
/// `[]`-returning skeleton until EPIC_03_ISSUE_06 — so the queue is wired but
/// not reachable end-to-end until that lands.
struct RightNowView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]
  @State private var pendingDoses: [PendingDose] = []

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RightNow")

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Right Now")
    }
    .task(id: medications.count) { reload() }
  }

  @ViewBuilder
  private var content: some View {
    if pendingDoses.isEmpty {
      VStack(spacing: 8) {
        Image(systemName: "checkmark.circle")
          .font(.title2)
        Text("All caught up")
          .font(.headline)
      }
      .foregroundStyle(.secondary)
    } else {
      TapThroughQueueView(pendingDoses: pendingDoses, onFinished: reload)
    }
  }

  private func reload() {
    do {
      pendingDoses = try PendingQueueSelector.pendingDoses(at: .now, in: modelContext)
    } catch {
      RightNowView.logger.error("Failed to compute pending doses: \(error.localizedDescription, privacy: .public)")
      pendingDoses = []
    }
  }
}

#Preview {
  RightNowView()
    .modelContainer(for: Medication.self, inMemory: true)
}
