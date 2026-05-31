import SwiftUI

/// A single PRN product row: the two-line summary from `PRNRowSummaryBuilder`,
/// tapping through to the quantity picker. The summary's variant text (SPEC §7.3)
/// is built upstream; this view just renders it.
struct PRNRowView: View {
  let summary: PRNRowSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      LiquidGlassTheme.Typography.medicationName(summary.firstLine)
      LiquidGlassTheme.Typography.footnote(summary.secondLine)
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
    }
    .padding(LiquidGlassTheme.Spacing.compact)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LiquidGlassTheme.Materials.surface)
    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.standard))
    .elevation(.raised)
  }
}
