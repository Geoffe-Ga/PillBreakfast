import SwiftUI

/// Opened when the "Snooze until…" notification action fires (SPEC §8.3). Stub for
/// now — the `DatePicker(.hourAndMinute)` and the reschedule land in
/// EPIC_06_ISSUE_03 / EPIC_06_ISSUE_02. Tapping Done dismisses.
struct SnoozeView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      LiquidGlassTheme.Typography.title("Snooze")
      LiquidGlassTheme.Typography.caption("Snooze stub — picker coming next issue")
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .multilineTextAlignment(.center)
      Button("Done") { dismiss() }
        .buttonStyle(.borderedProminent)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
  }
}

#Preview {
  SnoozeView()
}
