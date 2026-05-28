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
  @State private var writeFailed = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "TapThrough")

  var body: some View {
    Group {
      if finished || pendingDoses.isEmpty {
        QueueSuccessView(onDone: onFinished)
      } else {
        // Default page style per the issue. Swiping past a dose without acting on
        // it leaves that dose pending — it resurfaces on the next queue open (each
        // tap still logs its own screen's dose). The gesture flow is reworked in
        // EPIC 04 (press-and-hold), where swipe-past is constrained.
        TabView(selection: $index) {
          ForEach(Array(pendingDoses.enumerated()), id: \.offset) { offset, dose in
            doseScreen(dose).tag(offset)
          }
        }
        .tabViewStyle(.verticalPage)
      }
    }
    .alert("Dose not recorded", isPresented: $writeFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      // A silently-failed log is the most dangerous outcome for a med tracker;
      // tell the user so they re-tap to retry (the dose stays on screen).
      Text("Something went wrong saving this dose. Tap Mark Taken again to retry.")
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
      Color.clear.onAppear { advance(after: dose) }
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
      loggedDoses.remove(dose) // un-guard so the user can retry this dose
      writeFailed = true
      return
    }
    advance(after: dose)
  }

  /// Advances to the screen after `dose`'s own position, so a swipe-ahead-then-tap
  /// can't overshoot. A dose bypassed by swiping simply stays pending and
  /// resurfaces on the next queue open.
  private func advance(after dose: PendingDose) {
    guard let offset = pendingDoses.firstIndex(of: dose) else {
      finished = true
      return
    }
    if offset + 1 < pendingDoses.count {
      withAnimation { index = offset + 1 }
    } else {
      finished = true
    }
  }
}

#Preview {
  TapThroughQueueView(pendingDoses: [], onFinished: {})
    .modelContainer(for: Medication.self, inMemory: true)
}
