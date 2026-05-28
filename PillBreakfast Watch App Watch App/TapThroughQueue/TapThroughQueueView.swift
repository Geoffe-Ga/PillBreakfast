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
  @Query private var medications: [Medication]
  @State private var index = 0
  @State private var finished = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "TapThrough")

  var body: some View {
    Group {
      if finished || pendingDoses.isEmpty {
        QueueSuccessView(onDone: onFinished)
      } else {
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
      // The synced regimen lost this medication — skip the screen gracefully.
      ProgressView().onAppear { advance() }
    }
  }

  private func detail(for medication: Medication, quantity: Int) -> String {
    let mgPerUnit = medication.components.first?.dosagePerUnitMg ?? 0
    let unit = quantity == 1 ? "tablet" : "tablets"
    return "\(Int(mgPerUnit))mg · \(quantity) \(unit)"
  }

  private func log(_ dose: PendingDose, _ medication: Medication, status: DoseStatus) {
    do {
      try DoseEventWriter.writeDoseEvent(
        for: medication,
        scheduledFor: dose.scheduledFor,
        quantity: dose.quantity,
        status: status,
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
