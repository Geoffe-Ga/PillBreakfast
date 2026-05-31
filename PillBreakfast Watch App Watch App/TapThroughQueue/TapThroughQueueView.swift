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
  /// Name of the meal whose last dose was just confirmed; drives the
  /// `MealCompletionView` micro-state that auto-advances to the next dose.
  @State private var completedMealName: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "TapThrough")

  var body: some View {
    Group {
      if finished || pendingDoses.isEmpty {
        QueueSuccessView(onDone: onFinished)
      } else if let completedMealName {
        // Brief micro-state between meals once the last dose of one has been
        // confirmed. Auto-advances to the next dose's card (or the success
        // view if the queue is now empty) after Self.dwellSeconds.
        MealCompletionView(mealName: completedMealName) {
          self.completedMealName = nil
        }
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
        mealHeader: Self.mealHeader(for: dose),
        onMarkTaken: { log(dose, medication, status: .taken) },
        onSkip: { log(dose, medication, status: .skipped) }
      )
    } else {
      // The synced regimen lost this medication — skip the screen silently.
      Color.clear.onAppear { advance(after: dose) }
    }
  }

  /// "Pill Breakfast · 2 of 5" when an ordinal is set, "Pill Breakfast" for
  /// a singleton meal, nil for ungrouped doses. `static` so the wording is
  /// testable without a SwiftUI runtime.
  static func mealHeader(for dose: PendingDose) -> String? {
    guard let mealName = dose.mealName else { return nil }
    if let ordinal = dose.mealOrdinal {
      return "\(mealName) · \(ordinal.current) of \(ordinal.total)"
    }
    return mealName
  }

  private func detail(for medication: Medication, quantity: Int) -> String {
    let unit = quantity == 1 ? medication.unitForm.singularLabel : medication.unitForm.pluralLabel
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
  /// resurfaces on the next queue open. Inserts a 0.5 s `MealCompletionView`
  /// dwell when the user has just confirmed the last dose of a meal and
  /// another card still follows — the dwell view's `onAdvance` clears
  /// `completedMealName` and the next card slides up.
  private func advance(after dose: PendingDose) {
    // Reject a re-entry while the meal-completion dwell is on screen.
    // `MealCompletionView.onAdvance` is the only thing that should clear
    // `completedMealName`; ignoring spurious advances here makes a stray
    // second tap (or an out-of-band re-trigger) impossible to double-step
    // the queue.
    guard completedMealName == nil else { return }
    guard let offset = pendingDoses.firstIndex(of: dose) else {
      // Shouldn't happen — the dose came from this queue — but surface it rather
      // than ending silently if a future refactor passes a foreign dose.
      TapThroughQueueView.logger.error("advance(after:) given a dose not in the queue; finishing.")
      finished = true
      return
    }
    let nextOffset = offset + 1
    guard nextOffset < pendingDoses.count else {
      finished = true
      return
    }
    let nextDose = pendingDoses[nextOffset]
    if let mealName = dose.mealName, nextDose.mealID != dose.mealID {
      // Last dose of this meal AND more cards follow — show the micro-state
      // first so the user gets a beat between meals. Advance the index
      // *now* so the next card is ready behind the dwell view.
      index = nextOffset
      completedMealName = mealName
    } else {
      withAnimation { index = nextOffset }
    }
  }
}

#Preview {
  TapThroughQueueView(pendingDoses: [], onFinished: {})
    .modelContainer(for: Medication.self, inMemory: true)
}
