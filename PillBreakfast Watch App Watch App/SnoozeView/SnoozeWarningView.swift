import os
import SwiftData
import SwiftUI

/// Soft warning shown on the fourth consecutive snooze of one occurrence (SPEC
/// §8.3). Not a lockout — offers Snooze again, Skip (logs a skipped dose), or Take
/// now (back to the tap-through queue). The user is the authority.
struct SnoozeWarningView: View {
  let context: SnoozeContext
  let onSnoozeAgain: () -> Void
  let onResolved: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<Medication> { !$0.isArchived }) private var medications: [Medication]

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Snooze")

  var body: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      LiquidGlassTheme.Typography.title("Snoozed 3 times")
      LiquidGlassTheme.Typography.caption("Skip instead, or take it now?")
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .multilineTextAlignment(.center)

      Button("Skip", action: skip)
        .buttonStyle(.borderedProminent)
      Button("Take now", action: onResolved)
        .buttonStyle(.bordered)
      Button("Snooze again", action: onSnoozeAgain)
        .buttonStyle(.bordered)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
  }

  /// Logs a skipped dose for this occurrence and clears its snooze count, then
  /// dismisses. "Take now" routes back to the queue (where the dose is confirmed
  /// through the usual tap-through, including any high-risk press-and-hold).
  private func skip() {
    guard let scheduledDose = scheduledDose(),
          let medication = scheduledDose.medication
    else {
      SnoozeWarningView.logger.error("Skip: couldn't resolve dose \(context.scheduledDoseID, privacy: .public).")
      onResolved()
      return
    }
    do {
      try DoseEventWriter.writeDoseEvent(
        for: medication,
        scheduledFor: context.originalScheduledFor,
        quantity: scheduledDose.quantity,
        status: .skipped,
        loggedOn: .watch,
        at: .now,
        in: modelContext
      )
      try SnoozeRecordStore.reset(scheduledDoseID: context.scheduledDoseID, on: .now, in: modelContext)
    } catch {
      SnoozeWarningView.logger.error("Skip from snooze warning failed: \(error.localizedDescription, privacy: .public)")
    }
    onResolved()
  }

  private func scheduledDose() -> ScheduledDose? {
    let id = context.scheduledDoseID
    return try? modelContext.fetch(FetchDescriptor<ScheduledDose>(predicate: #Predicate { $0.id == id })).first
  }
}
