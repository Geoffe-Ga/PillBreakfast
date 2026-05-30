import os
import SwiftData
import SwiftUI

/// Per-day drill-down (SPEC §6.2): every `DoseEvent` from the chosen calendar
/// day in chronological order, plus the day's PRN ingredient running totals.
/// Read-only — the iPhone never offers a retroactive log surface.
struct DayDrillDownView: View {
  let date: Date

  @Environment(\.modelContext) private var modelContext
  @Query private var events: [DoseEvent]
  @State private var summary: DailySummary?

  private static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "HistoryDrillDown"
  )

  init(date: Date, calendar: Calendar = .current) {
    self.date = date
    let startOfDay = calendar.startOfDay(for: date)
    let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    _events = Query(
      filter: #Predicate<DoseEvent> { $0.takenAt >= startOfDay && $0.takenAt < nextDay },
      sort: [SortDescriptor(\DoseEvent.takenAt)]
    )
  }

  var body: some View {
    List {
      Section("Events") {
        ForEach(events) { event in
          DayEventRow(event: event)
        }
      }
      if let summary, !summary.ingredientTotals.isEmpty {
        Section("Ingredient totals") {
          ForEach(summary.ingredientTotals, id: \.ingredientID) { amount in
            HStack {
              Text(amount.ingredientName)
              Spacer()
              Text(Self.formatMg(amount.totalMg))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
          }
        }
      }
    }
    .overlay {
      // `ContentUnavailableView` rendered inside a `List` becomes a single
      // row instead of filling the surface; overlay puts it where it
      // belongs.
      if events.isEmpty {
        ContentUnavailableView(
          "No doses logged",
          systemImage: "tray",
          description: Text("Nothing was logged on this day.")
        )
      }
    }
    .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
    .navigationBarTitleDisplayMode(.inline)
    .task(id: date) {
      do {
        summary = try HistoryQueries.dailySummary(in: modelContext, day: date)
      } catch {
        // `.private` redaction — SwiftData error descriptions can embed model
        // summaries that include medication names (PHI).
        Self.logger.error(
          "Daily summary fetch failed: \(error.localizedDescription, privacy: .private)"
        )
        summary = nil
      }
    }
  }

  /// Round to whole mg — adequate precision for ceilings (e.g. 2400 mg/day Lithium).
  static func formatMg(_ mg: Double) -> String {
    "\(Int(mg.rounded())) mg"
  }
}

private struct DayEventRow: View {
  let event: DoseEvent

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: Self.symbolName(for: event.status))
        .foregroundStyle(.secondary)
        .accessibilityLabel(Self.accessibilityStatusLabel(for: event.status))
      VStack(alignment: .leading, spacing: 2) {
        Text(event.medication?.displayName ?? "Unknown medication")
          .font(.body)
        Text(event.takenAt.formatted(date: .omitted, time: .shortened))
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      Spacer()
      Text(Self.quantityLabel(event.quantity))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
  }

  static func symbolName(for status: DoseStatus) -> String {
    switch status {
    case .taken: "checkmark.circle"
    case .skipped: "xmark.circle"
    case .snoozed: "clock"
    }
  }

  static func accessibilityStatusLabel(for status: DoseStatus) -> String {
    switch status {
    case .taken: "Taken"
    case .skipped: "Skipped"
    case .snoozed: "Snoozed"
    }
  }

  static func quantityLabel(_ quantity: Int) -> String {
    quantity == 1 ? "1 pill" : "\(quantity) pills"
  }
}

#Preview {
  NavigationStack {
    DayDrillDownView(date: .now)
  }
  .modelContainer(for: DoseEvent.self, inMemory: true)
}
