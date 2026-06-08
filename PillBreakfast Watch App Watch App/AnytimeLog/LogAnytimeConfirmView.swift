import os
import SwiftData
import SwiftUI

/// Confirm screen for the anytime-log path. Reuses the queue's `MarkTakenView`
/// confirm UX (single-tap or press-and-hold based on `isHighRisk`) so the
/// safety contract matches the regular tap-through path. Writes `DoseEvent`
/// with `scheduledFor: nil` and `loggedOn: .watch`.
struct LogAnytimeConfirmView: View {
  let medication: Medication
  let onLogged: () -> Void

  @Environment(\.modelContext) private var modelContext
  @State private var writeFailed = false
  /// Prevents a rapid double-tap from logging the same dose twice within
  /// the same view lifetime (durable dedup is the user's responsibility
  /// when proactively logging — there's no scheduled-slot guard for an
  /// anytime dose).
  @State private var alreadyLogged = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "AnytimeLog")

  private var quantity: Int {
    AnytimeLogQuantity.defaultQuantity(for: medication)
  }

  private var detail: String {
    let unit = quantity == 1 ? medication.unitForm.singularLabel : medication.unitForm.pluralLabel
    if medication.components.count == 1, let mgPerUnit = medication.components.first?.dosagePerUnitMg {
      return "\(Int(mgPerUnit.rounded()))mg · \(quantity) \(unit)"
    }
    return "\(quantity) \(unit)"
  }

  var body: some View {
    MarkTakenView(
      medicationName: medication.displayName,
      detail: detail,
      isHighRisk: medication.isHighRisk,
      // Amber accent reserved for high-risk press-and-hold (CLAUDE.md).
      colorHex: medication.isHighRisk ? medication.colorHex : nil,
      onMarkTaken: confirm,
      onSkip: skip
    )
    .alert("Dose not recorded", isPresented: $writeFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Something went wrong saving this dose. Please try again.")
    }
  }

  private func confirm() {
    log(status: .taken)
  }

  private func skip() {
    log(status: .skipped)
  }

  private func log(status: DoseStatus) {
    guard !alreadyLogged else { return }
    alreadyLogged = true
    do {
      let event = try DoseEventWriter.writeDoseEvent(
        for: medication,
        scheduledFor: nil,
        quantity: quantity,
        status: status,
        loggedOn: .watch,
        at: .now,
        in: modelContext
      )
      // iPhone reverse-sync is non-fatal; the watch store is authoritative.
      do {
        try DoseEventBatchTransfer.transfer([event])
      } catch {
        LogAnytimeConfirmView.logger.error("Failed to queue anytime-dose transfer: \(error.localizedDescription, privacy: .public)")
      }
      // Refresh the complication's pending count (debounced; see WidgetReloadCoordinator).
      Task { await WidgetReloadCoordinator.shared.scheduleReload() }
      onLogged()
    } catch {
      LogAnytimeConfirmView.logger.error("Failed to log anytime dose: \(error.localizedDescription, privacy: .public)")
      alreadyLogged = false
      writeFailed = true
    }
  }
}
