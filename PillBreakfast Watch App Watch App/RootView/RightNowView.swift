import os
import SwiftData
import SwiftUI

/// Watch root. Routes to the tap-through queue when doses are pending, else
/// "All caught up". The pending set comes from `PendingQueueSelector`.
struct RightNowView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]
  @State private var pendingDoses: [PendingDose] = []

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RightNow")

  /// Re-keys the reload `.task` on anything that changes the pending set: which
  /// meds exist and each med's schedule. Keying on `medications.count` alone
  /// missed a same-count edit (e.g. moving a dose from 8:00 to 9:00).
  private var scheduleSignature: Int {
    var hasher = Hasher()
    for med in medications {
      hasher.combine(med.id)
      for dose in med.schedule {
        hasher.combine(dose.hour)
        hasher.combine(dose.minute)
        hasher.combine(dose.daysOfWeek)
        hasher.combine(dose.quantity)
      }
    }
    return hasher.finalize()
  }

  var body: some View {
    // Glass backs the whole screen (the outer container), nav bar included, so
    // the entire surface reads as one piece of Liquid Glass rather than a glass
    // panel under a system-opaque title.
    NavigationStack {
      content
        .navigationTitle("Right Now")
    }
    .glassBackground()
    .task(id: scheduleSignature) { reload() }
    // The window is time-relative, so re-evaluate when the app is foregrounded
    // (time has passed since the last reload even if no data changed).
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { reload() }
    }
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
      pendingDoses = try PendingQueueSelector().pendingDoses(at: .now, in: modelContext)
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
