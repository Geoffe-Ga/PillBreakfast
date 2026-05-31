import SwiftUI

/// A single PRN product row: the two-line summary from `PRNRowSummaryBuilder`,
/// tapping through to the quantity picker. The summary's variant text (SPEC §7.3)
/// is built upstream; this view just renders it.
struct PRNRowView: View {
  let summary: PRNRowSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      LiquidGlassTheme.Typography.medicationName(summary.firstLine)
      // `footnote` (13 pt) instead of `caption` (12 pt) so the running-total
      // / last-dose line stays legible on the watch's smallest face.
      LiquidGlassTheme.Typography.footnote(summary.secondLine)
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
    }
    .padding(.vertical, LiquidGlassTheme.Spacing.compact / 2)
    .elevation(.raised)
  }
}
