import SwiftUI

/// Stub 30-day heatmap. Renders each `HistoryDay` as a uniform-shade cell so
/// the layout and tap-through navigation are wired before the density encoding
/// lands in a follow-up.
struct HeatmapStubView: View {
  let days: [HistoryDay]

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 4) {
        ForEach(days) { day in
          NavigationLink(value: HistoryDayRoute(date: day.date)) {
            HistoryDayCell(day: day)
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

  var body: some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(.tertiary)
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
    HeatmapStubView(days: HistoryTabView.days(
      from: [],
      reference: .now,
      calendar: .current
    ))
  }
}
