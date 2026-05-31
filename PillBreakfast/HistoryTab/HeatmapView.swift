import SwiftUI

/// 30-day calendar heatmap (SPEC §6.2). Monochromatic `.primary` cells scaled
/// by per-day dose count and normalized to the window's busiest day. The grid
/// is row-major; the GitHub-style weekday-column layout is tracked in #178.
struct HeatmapView: View {
  let days: [HistoryDay]

  /// Minimum opacity for a day with any doses — keeps the cell visible against
  /// the Liquid Glass surface rather than dropping to invisible at low counts.
  static let minNonZeroOpacity: Double = 0.2
  static let maxOpacity: Double = 0.9
  /// Zero-dose cells render at this opacity so the grid still shows the day's
  /// shape; lower than `minNonZeroOpacity` so any logged dose is visibly above
  /// the baseline.
  static let zeroOpacity: Double = 0.05

  /// Legend-swatch ratios — quiet, mid, busy.
  private static let legendRatios: [Double] = [0.25, 0.55, 0.85]

  private static let columnSpacing: CGFloat = 4
  private static let columns: [GridItem] =
    Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: 7)

  /// Normalize a per-day count into a `.primary` opacity. Pure so the
  /// monotonicity / range invariants can be checked without rendering.
  static func opacity(for count: Int, maxCount: Int) -> Double {
    guard count > 0 else { return zeroOpacity }
    guard maxCount > 0 else { return zeroOpacity }
    let ratio = Double(count) / Double(maxCount)
    return minNonZeroOpacity + ratio * (maxOpacity - minNonZeroOpacity)
  }

  var body: some View {
    let maxCount = days.map(\.eventCount).max() ?? 0
    return ScrollView {
      VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.standard) {
        LazyVGrid(columns: Self.columns, spacing: Self.columnSpacing) {
          ForEach(days) { day in
            NavigationLink(value: HistoryDayRoute(date: day.date)) {
              HistoryDayCell(day: day, opacity: Self.opacity(for: day.eventCount, maxCount: maxCount))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Show day's events")
          }
        }
        intensityLegend(maxCount: maxCount)
      }
      .padding(LiquidGlassTheme.Spacing.standard)
    }
    .glassBackground()
  }

  /// Three-step monochromatic legend tied to the visible window's busiest day.
  private func intensityLegend(maxCount: Int) -> some View {
    HStack(spacing: LiquidGlassTheme.Spacing.compact) {
      LiquidGlassTheme.Typography.footnote("Quiet")
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      ForEach(Self.legendRatios, id: \.self) { ratio in
        RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.tight)
          .fill(.primary.opacity(Self.minNonZeroOpacity + ratio * (Self.maxOpacity - Self.minNonZeroOpacity)))
          .frame(width: 16, height: 12)
      }
      LiquidGlassTheme.Typography.footnote("Busy")
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      Spacer(minLength: 0)
      if maxCount > 0 {
        LiquidGlassTheme.Typography.footnote("Busiest: \(maxCount) \(maxCount == 1 ? "dose" : "doses")")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.legendAccessibilityLabel(maxCount: maxCount))
  }

  /// Coherent-sentence VoiceOver copy for the legend.
  static func legendAccessibilityLabel(maxCount: Int) -> String {
    if maxCount == 0 {
      return "Intensity legend, quiet to busy, no doses logged in this window."
    }
    return "Intensity legend, quiet to busy. Busiest day: \(maxCount) \(maxCount == 1 ? "dose" : "doses")."
  }
}

private struct HistoryDayCell: View {
  let day: HistoryDay
  let opacity: Double

  var body: some View {
    RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.tight)
      .fill(.primary.opacity(opacity))
      .aspectRatio(1, contentMode: .fit)
      .overlay {
        LiquidGlassTheme.Typography.caption("\(day.dayOfMonth)")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Self.accessibilityLabel(for: day))
  }

  static func accessibilityLabel(for day: HistoryDay) -> String {
    let dateText = day.date.formatted(date: .abbreviated, time: .omitted)
    let doseText = switch day.eventCount {
    case 0: "no doses"
    case 1: "1 dose"
    default: "\(day.eventCount) doses"
    }
    return "\(dateText), \(doseText)"
  }
}

#Preview {
  NavigationStack {
    HeatmapView(days: HistoryTabView.days(
      from: [],
      reference: .now,
      calendar: .current
    ))
  }
}
