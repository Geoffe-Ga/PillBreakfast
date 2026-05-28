import os
import SwiftData
import SwiftUI

/// Pages through the pending doses one screen at a time. Marking taken (or
/// skipping) writes a `DoseEvent` and advances; after the last one the success
/// view shows and then calls `onFinished` to return to the root.
struct TapThroughQueueView: View {
  let pendingDoses: [PendingDose]
  let onFinished: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]
  @State private var index = 0
  @State private var finished = false
  /// Guards against a rapid double-tap logging the same dose twice before the
  /// view advances.
  @State private var loggedDoses: Set<PendingDose> = []

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "TapThrough")

  var body: some View {
    Group {
      if finished || pendingDoses.isEmpty {
        QueueSuccessView(onDone: onFinished)
      } else {
        // Default page style per the issue. Swiping past a dose without acting on
        // it is possible but harmless (each tap logs its own screen's dose); the
        // gesture flow is reworked in EPIC 04 (press-and-hold) where this is constrained.
        TabView(selection: $index) {
          ForEach(Array(pendingDoses.enumerated()), id: \.offset) { offset, dose in
            doseScreen(dose).tag(offset)
          }
        }
        .tabViewStyle(.verticalPage)
      }
    }
  }

  @ViewBuilder
  private func doseScreen(_ dose: PendingDose) -> some View {
    if let medication = medications.first(where: { $0.id == dose.medicationID }) {
      MarkTakenView(
        medicationName: medication.displayName,
        detail: detail(for: medication, quantity: dose.quantity),
        colorHex: medication.colorHex,
        onMarkTaken: { log(dose, medication, status: .taken) },
        onSkip: { log(dose, medication, status: .skipped) }
      )
    } else {
      // The synced regimen lost this medication — skip the screen silently.
      Color.clear.onAppear { advance() }
    }
  }

  private func detail(for medication: Medication, quantity: Int) -> String {
    let unit = quantity == 1 ? "tablet" : "tablets"
    // A single summed mg figure is meaningless for combo products (you can't add
    // acetaminophen + aspirin mg), so show the per-unit mg only for single-ingredient
    // meds; combos show just the count.
    if medication.components.count == 1, let mgPerUnit = medication.components.first?.dosagePerUnitMg {
      return "\(Int(mgPerUnit.rounded()))mg · \(quantity) \(unit)"
    }
    return "\(quantity) \(unit)"
  }

  private func log(_ dose: PendingDose, _ medication: Medication, status: DoseStatus) {
    guard !loggedDoses.contains(dose) else { return }
    loggedDoses.insert(dose)
    do {
      try DoseEventWriter.writeDoseEvent(
        for: medication,
        scheduledFor: dose.scheduledFor,
        quantity: dose.quantity,
        status: status,
        loggedOn: .watch,
        at: .now,
        in: modelContext
      )
    } catch {
      TapThroughQueueView.logger.error("Failed to log dose: \(error.localizedDescription, privacy: .public)")
      return
    }
    advance()
  }

  private func advance() {
    if index + 1 < pendingDoses.count {
      withAnimation { index += 1 }
    } else {
      finished = true
    }
  }
}

#Preview {
  TapThroughQueueView(pendingDoses: [], onFinished: {})
    .modelContainer(for: Medication.self, inMemory: true)
}
