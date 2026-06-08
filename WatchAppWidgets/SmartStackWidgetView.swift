import SwiftUI
import WidgetKit

/// The Smart Stack card: the upcoming dose group (name + "N dose(s) · time") or
/// an "all caught up" idle state. Liquid Glass, monochrome — no amber even when
/// the group is high-risk (amber is reserved for the main-app press-and-hold).
struct SmartStackWidgetView: View {
  let entry: SmartStackEntry

  var body: some View {
    Group {
      if let group = entry.doseGroup {
        loaded(group)
      } else {
        idle
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .containerBackground(for: .widget) { Color.clear.glassEffect() }
  }

  private func loaded(_ group: SmartStackPlan.DoseGroupSummary) -> some View {
    VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.compact) {
      LiquidGlassTheme.Typography.headline(group.groupName)
        .lineLimit(2)
      LiquidGlassTheme.Typography.footnote(subtitle(group))
        .monospacedDigit()
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
    }
  }

  private var idle: some View {
    HStack(spacing: LiquidGlassTheme.Spacing.compact) {
      Image(systemName: "checkmark.circle")
      LiquidGlassTheme.Typography.footnote("All caught up")
    }
    .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
  }

  private func subtitle(_ group: SmartStackPlan.DoseGroupSummary) -> String {
    let unit = group.doseCount == 1 ? "dose" : "doses"
    let time = group.scheduledAt.formatted(date: .omitted, time: .shortened)
    return "\(group.doseCount) \(unit) · \(time)"
  }
}
