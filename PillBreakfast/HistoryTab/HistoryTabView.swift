import os
import SwiftData
import SwiftUI

/// iPhone History tab (SPEC §6.2). Hosts a 30-day heatmap of `DoseEvent`s, a
/// tap-through drill-down, and a per-session medication filter in the toolbar.
struct HistoryTabView: View {
  /// Inclusive window: today + 29 prior days. Anchored to the user's local
  /// calendar so the right-hand cell is "today" wherever the device is.
  static let windowDays = 30

  @Environment(\.modelContext) private var modelContext
  @Query private var doseEvents: [DoseEvent]
  /// All medications including archived — archived meds still need to be
  /// reachable in the filter so the user can review their history.
  @Query(sort: \Medication.displayName) private var medications: [Medication]
  @State private var filterMedicationID: UUID?
  /// Generated on tab appear so the toolbar `ShareLink` is one tap. The
  /// export ignores the medication filter for v1 — the share button always
  /// covers the full 30-day window per SPEC §6.2. A scoped export is
  /// possible follow-up work.
  @State private var exportedURL: URL?
  @State private var exportError: String?
  private let referenceDate: Date
  private let calendar: Calendar

  private static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "HistoryExport"
  )

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
    // Compute the cells once and share them between the heatmap and the
    // empty-state overlay; a computed property here would still be evaluated
    // twice per render pass.
    let cells = Self.days(
      from: doseEvents,
      reference: referenceDate,
      calendar: calendar,
      filterMedicationID: filterMedicationID
    )
    let totalEvents = cells.reduce(0) { $0 + $1.eventCount }
    return NavigationStack {
      HeatmapView(days: cells)
        .overlay {
          if totalEvents == 0 {
            ContentUnavailableView(
              "No history yet",
              systemImage: "tray",
              description: Text(Self.emptyDescription(forFilter: filterMedicationID, in: medications))
            )
          }
        }
        .navigationTitle("History")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            MedicationFilterMenu(
              medications: medications,
              selection: $filterMedicationID
            )
          }
          ToolbarItem(placement: .secondaryAction) {
            if let exportedURL {
              ShareLink(
                item: exportedURL,
                preview: SharePreview(
                  "PillBreakfast — last 30 days",
                  image: Image(systemName: "doc.text")
                )
              ) {
                Label("Export 30 days as PDF", systemImage: "square.and.arrow.up")
              }
            } else {
              // Spinner placeholder while the export runs (typically < 100 ms
              // at the 12-doses-per-day budget). Suppressed entirely if the
              // export errored; the alert surfaces the failure instead.
              ProgressView()
                .opacity(exportError == nil ? 1 : 0)
            }
          }
        }
        .navigationDestination(for: HistoryDayRoute.self) { route in
          DayDrillDownView(
            date: route.date,
            calendar: calendar,
            filterMedicationID: filterMedicationID
          )
        }
        .task { generateExport() }
        .alert(
          "Export failed",
          isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
          )
        ) {
          Button("Try Again") {
            exportError = nil
            generateExport()
          }
          Button("Cancel", role: .cancel) { exportError = nil }
        } message: {
          Text(exportError ?? "")
        }
    }
  }

  /// Runs on `.task` and on the alert's Try Again. Synchronous because
  /// `PDFExporter.exportLast30Days` is `@MainActor` synchronous — wrapping
  /// it in `async` would imply it's safe to await off-actor, which it isn't
  /// until the detached-render work tracked by the `TODO(#57)` lands.
  private func generateExport() {
    // Delete the previous export before writing a new one so a busy History
    // session (open tab → drill down → back → re-export) doesn't accumulate
    // orphaned UUID-suffixed PDFs in `tmp/` until iOS sweeps it.
    if let oldURL = exportedURL {
      try? FileManager.default.removeItem(at: oldURL)
      exportedURL = nil
    }
    do {
      exportedURL = try PDFExporter.exportLast30Days(
        from: modelContext,
        now: referenceDate,
        calendar: calendar
      )
      exportError = nil
    } catch {
      // `.private` redaction — the underlying error can carry SwiftData
      // model summaries that include medication names (PHI).
      Self.logger.error(
        "PDF export failed: \(error.localizedDescription, privacy: .private)"
      )
      exportedURL = nil
      exportError = "Couldn't generate the export. Please try again."
    }
  }

  /// Description for the empty-history overlay. The unfiltered case nudges
  /// the user toward the watch (the only logging surface); the filtered case
  /// names the medication so it's clear nothing was logged for *it*
  /// specifically rather than a global blank state.
  static func emptyDescription(forFilter selection: UUID?, in medications: [Medication]) -> String {
    if let id = selection, let name = medications.first(where: { $0.id == id })?.displayName {
      return "No \(name) doses logged in the last 30 days."
    }
    return "Log doses on your watch and they'll appear here."
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
