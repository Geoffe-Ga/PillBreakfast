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
  /// In-memory only — durable dedup comes from PendingQueueSelector (#26)
  /// filtering already-logged-today doses. This guard is purely a UX layer
  /// against rapid re-taps within one view lifetime, keyed on `PendingDose.id`
  /// so two doses with the same med/time/quantity stay distinct.
  @State private var loggedDoseIDs: Set<UUID> = []
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
        // `.verticalPage` provides watchOS 26's native paged transition — a glass
        // slide-and-refraction between pages (WWDC 2025 "Build with Liquid Glass
        // on watchOS"), so no custom transition is needed here. Glass backgrounds
        // live on the leaf screens (MarkTakenView / QueueSuccessView), not on this
        // router, to avoid stacking glass layers.
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
        isHighRisk: medication.isHighRisk,
        // Color is reserved for high-risk meds (CLAUDE.md); the baseline UI stays
        // monochromatic, so only pass a swatch when the med is high-risk.
        colorHex: medication.isHighRisk ? medication.colorHex : nil,
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
    guard !loggedDoseIDs.contains(dose.id) else { return }
    loggedDoseIDs.insert(dose.id)
    let event: DoseEvent
    do {
      event = try DoseEventWriter.writeDoseEvent(
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
      loggedDoseIDs.remove(dose.id) // un-guard so the user can retry this dose
      writeFailed = true
      return
    }
    // Transfer failure is non-fatal — the watch store is authoritative.
    do {
      try DoseEventBatchTransfer.transfer([event])
    } catch {
      TapThroughQueueView.logger.error("Failed to queue dose transfer: \(error.localizedDescription, privacy: .public)")
    }
    advance(after: dose)
  }

  /// Advances to the screen after `dose`'s own position, so a swipe-ahead-then-tap
  /// can't overshoot. A dose bypassed by swiping simply stays pending and
  /// resurfaces on the next queue open.
  private func advance(after dose: PendingDose) {
    guard let offset = pendingDoses.firstIndex(of: dose) else {
      // Shouldn't happen — the dose came from this queue — but surface it rather
      // than ending silently if a future refactor passes a foreign dose.
      TapThroughQueueView.logger.error("advance(after:) given a dose not in the queue; finishing.")
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
