import os
import SwiftData
import SwiftUI

/// iPhone History tab (SPEC §6.2). Hosts a 30-day heatmap of `DoseEvent`s, a
/// tap-through drill-down, and a per-session medication filter in the toolbar.
///
/// `referenceDate` lives here (as `@State`) rather than on the inner
/// `HistoryContent` so it can slide forward when the calendar day changes
/// without rebuilding the tab from scratch. The inner view re-inits its
/// `@Query` whenever `referenceDate` changes, keeping the heatmap and the PDF
/// export in sync across midnight.
struct HistoryTabView: View {
  /// Inclusive window: today + 29 prior days. Anchored to the user's local
  /// calendar so the right-hand cell is "today" wherever the device is.
  static let windowDays = 30

  @State private var referenceDate: Date
  private let calendar: Calendar

  private static let rolloverLogger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "HistoryRollover"
  )

  init(referenceDate: Date = .now, calendar: Calendar = .current) {
    _referenceDate = State(initialValue: referenceDate)
    self.calendar = calendar
  }

  var body: some View {
    HistoryContent(referenceDate: referenceDate, calendar: calendar)
      .task { await advanceAcrossMidnight() }
  }

  /// Long-running task: keep the window anchored on today as the calendar
  /// day rolls over while the tab is foregrounded. Cancelled on view
  /// disappear (tab switch, app background) — re-establishes on re-appear.
  ///
  /// `@MainActor` is explicit so the isolation contract is visible at the
  /// declaration site; the body mutates `@State referenceDate`, which has
  /// to happen on the main actor.
  @MainActor
  private func advanceAcrossMidnight() async {
    // First, catch up if the tab re-appears after the system rolled over
    // while we were off-screen (e.g. user switched tabs through midnight).
    let today = calendar.startOfDay(for: .now)
    if calendar.startOfDay(for: referenceDate) != today {
      referenceDate = .now
    }
    while !Task.isCancelled {
      guard let nextMidnight = Self.nextDayBoundary(after: .now, calendar: calendar) else {
        // Day arithmetic on a valid calendar can't fail in practice; assert
        // in debug so an SDK regression surfaces in tests, and log at .fault
        // so a release-build silent-exit leaves a breadcrumb in OSLog.
        assertionFailure("nextDayBoundary returned nil — day arithmetic should not fail on a valid calendar")
        Self.rolloverLogger.fault("nextDayBoundary returned nil — day arithmetic failed; rollover task exiting")
        return
      }
      let secondsUntilMidnight = nextMidnight.timeIntervalSinceNow
      // `> 0` only: scheduler jitter can wake us slightly after midnight,
      // in which case we skip the sleep, advance the anchor immediately,
      // and the next iteration sleeps until the *following* midnight. The
      // exact-midnight case is pinned by `nextDayBoundaryFromExactMidnight…`.
      if secondsUntilMidnight > 0 {
        do {
          try await Task.sleep(for: .seconds(secondsUntilMidnight))
        } catch {
          return // cancelled
        }
      }
      referenceDate = .now
    }
  }

  /// Start of the calendar day strictly after `now`. Pure helper so tests pin
  /// the rollover semantics without spinning up a SwiftUI runtime; the live
  /// task in `advanceAcrossMidnight` calls this to decide how long to sleep.
  static func nextDayBoundary(after now: Date, calendar: Calendar) -> Date? {
    let startOfDay = calendar.startOfDay(for: now)
    return calendar.date(byAdding: .day, value: 1, to: startOfDay)
  }

  /// Description for the empty-history overlay; falls back to generic copy if the filter no longer matches a med.
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

/// Inner view that actually renders the heatmap, toolbar, and export. Pulled
/// out of `HistoryTabView` so its `@Query` can re-establish when the parent
/// passes a new `referenceDate` — SwiftUI re-runs `init` whenever a stored
/// property of a view value changes, which is exactly the seam `@Query` needs
/// to pick up a new predicate.
private struct HistoryContent: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var doseEvents: [DoseEvent]
  /// All medications including archived — archived meds still need to be
  /// reachable in the filter so the user can review their history.
  @Query(sort: \Medication.displayName) private var medications: [Medication]
  /// Preserved across a midnight rollover: SwiftUI keeps `@State` when the
  /// view's structural identity is unchanged, and the parent always renders
  /// `HistoryContent(...)` in the same position. Only `@Query` re-establishes,
  /// and only because its predicate is captured at `init`.
  @State private var filterMedicationID: UUID?
  /// Regenerated whenever `referenceDate` changes so the share-sheet PDF
  /// covers the same window the heatmap is showing — without this, a session
  /// that crossed midnight could share yesterday's window while the heatmap
  /// renders today's.
  @State private var exportedURL: URL?
  @State private var exportError: String?
  /// In-flight guard against two concurrent `generateExport` calls.
  @State private var isExporting = false
  private let referenceDate: Date
  private let calendar: Calendar

  private static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "HistoryExport"
  )

  init(referenceDate: Date, calendar: Calendar) {
    let start = HistoryTabView.windowStart(reference: referenceDate, calendar: calendar)
    _doseEvents = Query(
      filter: #Predicate<DoseEvent> { $0.takenAt >= start },
      sort: [SortDescriptor(\DoseEvent.takenAt)]
    )
    self.referenceDate = referenceDate
    self.calendar = calendar
  }

  var body: some View {
    // Hoist once: heatmap init and isEmpty check share the same cells.
    let cells = HistoryTabView.days(
      from: doseEvents,
      reference: referenceDate,
      calendar: calendar,
      filterMedicationID: filterMedicationID
    )
    let isEmpty = cells.allSatisfy { $0.eventCount == 0 }
    NavigationStack {
      HeatmapView(days: cells)
        .overlay {
          if isEmpty {
            ContentUnavailableView(
              "No history yet",
              systemImage: "tray",
              description: Text(HistoryTabView.emptyDescription(forFilter: filterMedicationID, in: medications))
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
        // `.task(id:)` rather than plain `.task` so the export regenerates
        // when the window slides forward across midnight.
        .task(id: referenceDate) { await generateExport() }
        .alert(
          "Export failed",
          isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
          )
        ) {
          Button("Try Again") {
            exportError = nil
            Task { await generateExport() }
          }
          Button("Cancel", role: .cancel) { exportError = nil }
        } message: {
          Text(exportError ?? "")
        }
    }
  }

  /// Runs on `.task` and on the alert's Try Again. `async` because
  /// `PDFExporter.exportLast30Days` is async — the collect phase stays on
  /// the MainActor (this view's isolation), but the render runs on a
  /// detached `userInitiated` task so a dense export doesn't stall the UI.
  private func generateExport() async {
    // Drop redundant calls so rapid "Try Again" taps (or a `.task(id:)`
    // restart racing with a pending alert action) can't spawn concurrent
    // exports and leak a PDF into `tmp/` whichever one finishes second.
    //
    // Known limitation: if `.task(id: referenceDate)` fires at midnight
    // while an export is in flight, the post-midnight re-export is
    // swallowed and the share-sheet PDF stays anchored on the prior
    // window until the user re-enters the tab or taps Try Again.
    // Acceptable for v1; the alternative (cancellable export with
    // structured cancellation) is tracked in #153.
    if isExporting { return }
    isExporting = true
    defer { isExporting = false }
    // Delete the previous export before writing a new one so a busy History
    // session (open tab → drill down → back → re-export) doesn't accumulate
    // orphaned UUID-suffixed PDFs in `tmp/` until iOS sweeps it.
    if let oldURL = exportedURL {
      try? FileManager.default.removeItem(at: oldURL)
      exportedURL = nil
    }
    do {
      exportedURL = try await PDFExporter.exportLast30Days(
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
