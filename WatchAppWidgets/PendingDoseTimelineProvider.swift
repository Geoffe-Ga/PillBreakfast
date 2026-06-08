import Foundation
import os
import SwiftData
import WidgetKit

/// One timeline sample for the pending-dose complication.
///
/// `pendingCount` is deliberately `nil` in the Phase 7 skeleton (#48) — the
/// circular complication renders `"--"`. #49 replaces the stub provider with a
/// real one that fills `pendingCount` from `PendingQueueSelector`.
nonisolated struct PendingDoseEntry: TimelineEntry {
  let date: Date
  let pendingCount: Int?
}

extension PendingDoseEntry {
  /// What the complication renders: `nil` (the stub) → `"--"`, `0` → `"✓"`,
  /// positive → the count. #49 populates `pendingCount` so this shows real data.
  /// Logic lives in `Shared/PendingDoseDisplay` so it's CI-tested (the widget
  /// extension has no test target yet).
  var displayText: String {
    PendingDoseDisplay.text(forCount: pendingCount)
  }

  /// Whether any dose is due now — drives accent/emphasis in later families.
  var hasPending: Bool {
    PendingDoseDisplay.hasPending(pendingCount)
  }
}

/// Pure, `Context`-free timeline construction.
///
/// Kept separate from the provider so the entry shape and reload cadence can be
/// unit-tested without fabricating a `TimelineProviderContext` (which has no
/// public initializer).
nonisolated enum PendingDoseTimeline {
  /// The `pendingCount: nil` ("--") entry — used for `placeholder` and as the
  /// error fallback when the store can't be read.
  static func entry(at date: Date) -> PendingDoseEntry {
    PendingDoseEntry(date: date, pendingCount: nil)
  }
}

/// Drives the complication from the shared App Group store. `PendingQueueSelector`
/// and `PersistenceController`'s statics are main-actor-isolated (project default
/// isolation), so the nonisolated `TimelineProvider` callbacks hop to the main
/// actor for the read; pure date planning lives in `WidgetTimelinePlan`.
nonisolated struct PendingDoseTimelineProvider: TimelineProvider {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Widget")
  private static let lookahead: TimeInterval = 24 * 60 * 60

  func placeholder(in context: Context) -> PendingDoseEntry {
    PendingDoseTimeline.entry(at: .now)
  }

  /// WidgetKit calls these on the main thread on watchOS. Compute the (Sendable)
  /// result inside `assumeIsolated`, then call `completion` out here in the
  /// nonisolated context — so the non-Sendable `completion` never crosses an
  /// isolation boundary (a `Task`, or capturing it *inside* the closure, would).
  func getSnapshot(in context: Context, completion: @escaping (PendingDoseEntry) -> Void) {
    let entry = MainActor.assumeIsolated { Self.snapshot(at: .now) }
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PendingDoseEntry>) -> Void) {
    let entries = MainActor.assumeIsolated { Self.timelineEntries(at: .now) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  // MARK: - Reads (main-actor: PendingQueueSelector + the App Group statics are isolated)

  @MainActor
  static func snapshot(at now: Date) -> PendingDoseEntry {
    PendingDoseEntry(date: now, pendingCount: try? pendingCount(at: now))
  }

  /// One entry at `now` plus one at each window opening/closing edge over the
  /// next 24 h, each carrying the real pending count. Any read failure degrades
  /// to a single `"--"` entry — the extension never traps. The caller wraps these
  /// in a `.atEnd` `Timeline` (WidgetKit re-requests after the horizon; #52 also
  /// reloads on dose writes).
  @MainActor
  static func timelineEntries(at now: Date) -> [PendingDoseEntry] {
    do {
      let context = try makeContext()
      let selector = PendingQueueSelector()
      let meds = try activeMaintenance(in: context)
      let dates = ([now] + WidgetTimelinePlan.transitionDates(
        forMaintenance: meds,
        from: now,
        to: now.addingTimeInterval(lookahead),
        calendar: .current,
        windowMinutes: selector.windowMinutes
      )).sorted()
      return try dates.map { date in
        try PendingDoseEntry(date: date, pendingCount: selector.pendingDoses(at: date, in: context).count)
      }
    } catch {
      logger.error("Widget timeline build failed: \(error.localizedDescription, privacy: .public)")
      return [PendingDoseTimeline.entry(at: now)]
    }
  }

  @MainActor
  private static func pendingCount(at date: Date) throws -> Int {
    let context = try makeContext()
    return try PendingQueueSelector().pendingDoses(at: date, in: context).count
  }

  /// Non-archived maintenance meds. `kind` is filtered in memory (matching
  /// `PendingQueueSelector` / `NotificationScheduler`, which sidestep enum
  /// `#Predicate` quirks).
  @MainActor
  private static func activeMaintenance(in context: ModelContext) throws -> [Medication] {
    try context
      .fetch(FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived }))
      .filter { $0.kind == .maintenance }
  }

  /// Opens the extension's OWN read-only `ModelContext` against the App Group
  /// store — never `PersistenceController.shared`, which would run the ingredient
  /// seeder (a write) in this read-only process. No `context.save()` ever.
  ///
  /// `@MainActor` is required: this project sets
  /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which isolates even `static`
  /// members, so `PersistenceController.schema` / `appGroupStoreURL` are
  /// main-actor-isolated and a nonisolated caller can't reach them.
  @MainActor
  private static func makeContext() throws -> ModelContext {
    let configuration = ModelConfiguration(url: PersistenceController.appGroupStoreURL)
    let container = try ModelContainer(for: PersistenceController.schema, configurations: configuration)
    return ModelContext(container)
  }
}
