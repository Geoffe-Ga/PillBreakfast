import SwiftData
import SwiftUI

/// iPhone History tab (SPEC §6.2). Hosts a 30-day heatmap of `DoseEvent`s, a
/// tap-through drill-down, and a per-session medication filter in the toolbar.
struct HistoryTabView: View {
  /// Inclusive window: today + 29 prior days. Anchored to the user's local
  /// calendar so the right-hand cell is "today" wherever the device is.
  static let windowDays = 30

  @Query private var doseEvents: [DoseEvent]
  /// All medications including archived — archived meds still need to be
  /// reachable in the filter so the user can review their history.
  @Query(sort: \Medication.displayName) private var medications: [Medication]
  @State private var filterMedicationID: UUID?
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
      HeatmapView(days: Self.days(
        from: doseEvents,
        reference: referenceDate,
        calendar: calendar,
        filterMedicationID: filterMedicationID
      ))
      .navigationTitle("History")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          MedicationFilterMenu(
            medications: medications,
            selection: $filterMedicationID
          )
        }
      }
      .navigationDestination(for: HistoryDayRoute.self) { route in
        DayDrillDownView(
          date: route.date,
          calendar: calendar,
          filterMedicationID: filterMedicationID
        )
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
  /// When `filterMedicationID` is non-nil, events not matching it are excluded
  /// from the per-day count so the heatmap intensity scopes to that medication.
  static func days(
    from doseEvents: [DoseEvent],
    reference: Date,
    calendar: Calendar,
    filterMedicationID: UUID? = nil
  ) -> [HistoryDay] {
    let scoped: [DoseEvent] = if let medicationID = filterMedicationID {
      doseEvents.filter { $0.medication?.id == medicationID }
    } else {
      doseEvents
    }
    let buckets = Dictionary(grouping: scoped) { calendar.startOfDay(for: $0.takenAt) }
    let startOfReference = calendar.startOfDay(for: reference)
    return (0 ..< windowDays).reversed().compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfReference) else { return nil }
      let count = buckets[date]?.count ?? 0
      let dayOfMonth = calendar.component(.day, from: date)
      return HistoryDay(date: date, dayOfMonth: dayOfMonth, eventCount: count)
    }
  }
}

/// Toolbar medication-filter control. "All medications" maps to a `nil`
/// `selection`; each medication tags its own `id`. Per-session — the
/// filter resets when the tab is rebuilt.
struct MedicationFilterMenu: View {
  let medications: [Medication]
  @Binding var selection: UUID?

  var body: some View {
    Menu {
      Picker("Filter by medication", selection: $selection) {
        Text("All medications").tag(UUID?.none)
        ForEach(medications) { medication in
          Text(medication.displayName).tag(UUID?.some(medication.id))
        }
      }
    } label: {
      Label(Self.labelText(for: selection, in: medications), systemImage: "line.3.horizontal.decrease.circle")
    }
    .accessibilityLabel("Filter by medication")
    .accessibilityHint("Scope the heatmap and drill-down to one medication")
  }

  /// Title for the toolbar control. Falls back to "All medications" when the
  /// stored selection refers to a medication that no longer exists (e.g. a
  /// hard-delete sneaking in around the archive flow).
  static func labelText(for selection: UUID?, in medications: [Medication]) -> String {
    guard let id = selection else { return "All medications" }
    return medications.first { $0.id == id }?.displayName ?? "All medications"
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
    .modelContainer(for: [Medication.self, DoseEvent.self], inMemory: true)
}
