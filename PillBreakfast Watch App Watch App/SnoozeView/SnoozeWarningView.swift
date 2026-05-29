import os
import SwiftUI

/// Soft warning shown on the fourth consecutive snooze of one occurrence (SPEC
/// §8.3). Not a lockout — offers Snooze again, Skip (logs a skipped dose), or Take
/// now (back to the tap-through queue). The user is the authority.
struct SnoozeWarningView: View {
  let context: SnoozeContext
  let onSnoozeAgain: () -> Void
  let onResolved: () -> Void

  @Environment(\.modelContext) private var modelContext
  @State private var skipFailed = false

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
    .alert("Couldn't skip", isPresented: $skipFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("The dose couldn't be skipped. Try again.")
    }
  }

  /// "Take now" routes back to the queue (where the dose is confirmed through the
  /// usual tap-through, including any high-risk press-and-hold), so it just resolves.
  private func skip() {
    do {
      try SnoozeSkip.skip(
        scheduledDoseID: context.scheduledDoseID,
        originalScheduledFor: context.originalScheduledFor,
        in: modelContext
      )
      onResolved()
    } catch {
      // Stay visible on failure so a silently-not-skipped dose can't slip through.
      SnoozeWarningView.logger.error("Skip from snooze warning failed: \(error.localizedDescription, privacy: .private)")
      skipFailed = true
    }
  }
}
