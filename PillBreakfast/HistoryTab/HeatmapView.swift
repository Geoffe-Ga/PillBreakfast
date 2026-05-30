import SwiftUI

/// 30-day calendar heatmap with monochromatic intensity. Cell shade is one hue
/// (`.primary`) with opacity scaled by per-day dose count, normalized to the
/// busiest day in the window so a quiet week still reads at the top end
/// rather than washing out (SPEC §6.2; CLAUDE.md "color reserved for high-risk
/// meds").
struct HeatmapView: View {
  let days: [HistoryDay]

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

  /// Minimum opacity for a day with any doses — keeps the cell visible against
  /// the Liquid Glass surface rather than dropping to invisible at low counts.
  static let minNonZeroOpacity: Double = 0.2
  static let maxOpacity: Double = 0.9
  /// Zero-dose cells render at this opacity so the grid still shows the day's
  /// shape; lower than `minNonZeroOpacity` so any logged dose is visibly above
  /// the baseline.
  static let zeroOpacity: Double = 0.05

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
      LazyVGrid(columns: columns, spacing: 4) {
        ForEach(days) { day in
          NavigationLink(value: HistoryDayRoute(date: day.date)) {
            HistoryDayCell(day: day, opacity: Self.opacity(for: day.eventCount, maxCount: maxCount))
          }
          .buttonStyle(.plain)
        }
      }
      .padding()
    }
    .glassBackground()
  }
}

private struct HistoryDayCell: View {
  let day: HistoryDay
  let opacity: Double

  var body: some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(.primary.opacity(opacity))
      .aspectRatio(1, contentMode: .fit)
      .overlay {
        Text("\(day.dayOfMonth)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Self.accessibilityLabel(for: day))
  }

  static func accessibilityLabel(for day: HistoryDay) -> String {
    let dateText = day.date.formatted(date: .abbreviated, time: .omitted)
    let doseText = day.eventCount == 1 ? "1 dose" : "\(day.eventCount) doses"
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
