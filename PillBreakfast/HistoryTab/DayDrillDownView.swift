import os
import SwiftData
import SwiftUI

/// Per-day drill-down (SPEC §6.2): every `DoseEvent` from the chosen calendar
/// day in chronological order, plus the day's PRN ingredient running totals.
/// Read-only — the iPhone never offers a retroactive log surface.
struct DayDrillDownView: View {
  let date: Date
  let filterMedicationID: UUID?

  @Environment(\.modelContext) private var modelContext
  @Query private var events: [DoseEvent]
  @State private var summary: DailySummary?

  private static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "HistoryDrillDown"
  )

  init(date: Date, calendar: Calendar = .current, filterMedicationID: UUID? = nil) {
    self.date = date
    self.filterMedicationID = filterMedicationID
    let startOfDay = calendar.startOfDay(for: date)
    let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    let medicationID = filterMedicationID
    _events = Query(
      filter: #Predicate<DoseEvent> {
        $0.takenAt >= startOfDay
          && $0.takenAt < nextDay
          && (medicationID == nil || $0.medication?.id == medicationID)
      },
      sort: [SortDescriptor(\DoseEvent.takenAt)]
    )
  }

  var body: some View {
    List {
      Section {
        // Pinned at the top so the day's safety-relevant totals lead the page.
        if let summary, !summary.ingredientTotals.isEmpty {
          // Card bleeds to the section edges — the card's own padding handles
          // the inner gutter, and zeroing leading/trailing here lets the
          // elevated background reach the visual edge of the list section.
          ingredientSummaryCard(summary)
            .listRowInsets(EdgeInsets(top: LiquidGlassTheme.Spacing.compact, leading: 0, bottom: LiquidGlassTheme.Spacing.standard, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
      }
      Section {
        ForEach(events) { event in
          DayEventRow(event: event)
        }
      } header: {
        LiquidGlassTheme.Typography.headline("Events")
          .textCase(nil)
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .glassBackground()
    .overlay {
      // `ContentUnavailableView` rendered inside a `List` becomes a single
      // row instead of filling the surface; overlay puts it where it
      // belongs.
      if events.isEmpty {
        PillEmptyStateView(
          title: "No doses logged",
          systemImage: "tray",
          description: "Nothing was logged on this day."
        )
      }
    }
    .navigationTitle(date.formatted(date: .complete, time: .omitted))
    .toolbarTitleDisplayMode(.inline)
    // Ingredient totals lag the `@Query` event list by one sync when new
    // events arrive mid-view: `@Query` re-renders reactively, but this
    // `.task` only re-runs when `date` changes. Acceptable for a read-only
    // history surface.
    .task(id: SummaryTaskID(date: date, medicationID: filterMedicationID)) {
      do {
        summary = try HistoryQueries.dailySummary(
          in: modelContext,
          day: date,
          medicationID: filterMedicationID
        )
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

  /// Hero-card treatment for the day's ingredient totals — `CornerRadius.card`,
  /// elevated glass, monospaced mg figures so digits don't shift between rows.
  private func ingredientSummaryCard(_ summary: DailySummary) -> some View {
    VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.compact) {
      LiquidGlassTheme.Typography.headline("Ingredient totals")
        .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
      ForEach(summary.ingredientTotals, id: \.ingredientID) { amount in
        HStack {
          LiquidGlassTheme.Typography.footnote(amount.ingredientName)
            .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
          Spacer()
          LiquidGlassTheme.Typography.dosage(MgFormatter.format(amount.totalMg))
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }
      }
    }
    .padding(LiquidGlassTheme.Spacing.standard)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LiquidGlassTheme.Materials.surface)
    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.card))
    .elevation(.raised)
  }
}

/// Compound `.task(id:)` key — re-fires the summary fetch whenever the date
/// or the filter changes. SwiftUI's `.task(id:)` accepts any `Equatable`, so
/// the synthesized conformance does the work.
private struct SummaryTaskID: Equatable {
  let date: Date
  let medicationID: UUID?
}

private struct DayEventRow: View {
  /// Inter-line spacing inside an event row — sub-compact on purpose so
  /// the name and the timestamp hug as one row, matching the regimen-row
  /// rhythm in `RegimenListView`.
  static let rowLineSpacing: CGFloat = 2

  let event: DoseEvent

  var body: some View {
    HStack(spacing: LiquidGlassTheme.Spacing.standard) {
      Image(systemName: Self.symbolName(for: event.status))
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .font(.title3)
        .accessibilityLabel(Self.accessibilityStatusLabel(for: event.status))
      VStack(alignment: .leading, spacing: Self.rowLineSpacing) {
        LiquidGlassTheme.Typography.headline(event.medication?.displayName ?? "Unknown medication")
          .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
        LiquidGlassTheme.Typography.footnote(event.takenAt.formatted(date: .omitted, time: .shortened))
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
          .monospacedDigit()
      }
      Spacer()
      LiquidGlassTheme.Typography.footnote(Self.quantityLabel(event.quantity))
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .monospacedDigit()
    }
    .padding(.vertical, LiquidGlassTheme.Spacing.compact)
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
