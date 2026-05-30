import SwiftData
import SwiftUI

/// iPhone History tab skeleton (SPEC §6.2). Hosts a 30-day heatmap of
/// `DoseEvent`s and a tap-through drill-down. Cell density is uniform in this
/// skeleton; real intensity shading lands in a follow-up.
struct HistoryTabView: View {
  /// Inclusive window: today + 29 prior days. Anchored to the user's local
  /// calendar so the right-hand cell is "today" wherever the device is.
  static let windowDays = 30

  @Query private var doseEvents: [DoseEvent]
  private let referenceDate: Date
  private let calendar: Calendar

  /// `referenceDate` is frozen at init; a session past midnight keeps the prior window until the density follow-up wires live refresh.
  init(referenceDate: Date = .now, calendar: Calendar = .current) {
    let start = HistoryTabView.windowStart(reference: referenceDate, calendar: calendar)
    _doseEvents = Query(
      filter: #Predicate<DoseEvent> { $0.takenAt >= start },
      sort: [SortDescriptor(\DoseEvent.takenAt)]
    )
    self.referenceDate = referenceDate
    self.calendar = calendar
  }

  var body: some View {
    NavigationStack {
      HeatmapStubView(days: Self.days(from: doseEvents, reference: referenceDate, calendar: calendar))
        .navigationTitle("History")
        .navigationDestination(for: HistoryDayRoute.self) { route in
          DayDrillDownStubView(date: route.date)
        }
    }
  }

  /// Start-of-day for the oldest cell in the 30-day window.
  static func windowStart(reference: Date, calendar: Calendar) -> Date {
    let startOfReference = calendar.startOfDay(for: reference)
    return calendar.date(byAdding: .day, value: -(windowDays - 1), to: startOfReference) ?? startOfReference
  }

  /// Build the heatmap day cells. Oldest first → today last so the grid reads
  /// left-to-right top-to-bottom. Events outside the window are silently
  /// excluded — the @Query already pre-filters, but the bucket lookup is
  /// keyed on in-window day starts so out-of-window events would not match.
  static func days(from doseEvents: [DoseEvent], reference: Date, calendar: Calendar) -> [HistoryDay] {
    let buckets = Dictionary(grouping: doseEvents) { calendar.startOfDay(for: $0.takenAt) }
    let startOfReference = calendar.startOfDay(for: reference)
    return (0 ..< windowDays).reversed().compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfReference) else { return nil }
      let count = buckets[date]?.count ?? 0
      let dayOfMonth = calendar.component(.day, from: date)
      return HistoryDay(date: date, dayOfMonth: dayOfMonth, eventCount: count)
    }
  }
}

/// One cell in the heatmap: a calendar day plus the count of `DoseEvent`s
/// recorded against it. `Identifiable` on the day-start `date` so the grid's
/// `ForEach` has a stable key.
struct HistoryDay: Identifiable, Hashable {
  let date: Date
  let dayOfMonth: Int
  let eventCount: Int

  var id: Date {
    date
  }
}

/// NavigationStack route from a heatmap cell to its drill-down.
struct HistoryDayRoute: Hashable {
  let date: Date
}

#Preview {
  HistoryTabView()
    .modelContainer(for: DoseEvent.self, inMemory: true)
}
