import os
import SwiftUI

/// Soft warning shown on the fourth consecutive snooze of one occurrence (SPEC
/// §8.3). Not a lockout — offers Snooze again, Skip (logs a skipped dose), or Take
/// now (back to the tap-through queue). The user is the authority.
struct SnoozeWarningView: View {
  let context: SnoozeContext
  let snoozeCount: Int
  let onSnoozeAgain: () -> Void
  let onResolved: () -> Void

  @Environment(\.modelContext) private var modelContext
  @State private var skipFailed = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Snooze")

  var body: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      LiquidGlassTheme.Typography.display("Snoozed \(snoozeCount) times")
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
      LiquidGlassTheme.Typography.footnote("Skip instead, or take it now?")
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .multilineTextAlignment(.center)

      // Lead with the lightest action: on the Digital Crown the first button is the
      // most reachable, so the irreversible Skip goes last to avoid accidental taps.
      Button("Snooze again", action: onSnoozeAgain)
        .buttonStyle(.bordered)
      // "Take now" doesn't cancel the pending snooze trigger — a spurious
      // reminder could fire before the eventual confirm rebuilds notifications.
      // Accepted gap on this soft-nudge path.
      Button("Take now", action: onResolved)
        .buttonStyle(.borderedProminent)
      Button("Skip", action: skip)
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

  /// Logs a skipped dose and clears this occurrence's snooze count. "Take now" (via
  /// `onResolved`) only dismisses to the tap-through queue, where the dose is confirmed
  /// through the usual flow (press-and-hold for high-risk) — the count is intentionally
  /// left intact on that path, since merely dismissing the nudge isn't a resolution.
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
