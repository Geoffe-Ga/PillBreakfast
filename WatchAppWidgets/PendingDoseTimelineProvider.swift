import Foundation
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
  /// Stub reload cadence. #52 will drive reloads from dose writes instead of
  /// a fixed interval.
  static let reloadInterval: TimeInterval = 15 * 60

  static func entry(at date: Date) -> PendingDoseEntry {
    PendingDoseEntry(date: date, pendingCount: nil)
  }

  static func nextReload(after date: Date) -> Date {
    date.addingTimeInterval(reloadInterval)
  }
}

/// Stub provider: every callback returns a single `pendingCount: nil` entry and
/// asks WidgetKit to reload ~15 minutes later. No SwiftData, no networking —
/// that wiring arrives in #49 / #52.
nonisolated struct PendingDoseTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> PendingDoseEntry {
    PendingDoseTimeline.entry(at: .now)
  }

  func getSnapshot(in context: Context, completion: @escaping (PendingDoseEntry) -> Void) {
    completion(PendingDoseTimeline.entry(at: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PendingDoseEntry>) -> Void) {
    let now = Date.now
    let timeline = Timeline(
      entries: [PendingDoseTimeline.entry(at: now)],
      policy: .after(PendingDoseTimeline.nextReload(after: now))
    )
    completion(timeline)
  }

  /// Opens the extension's OWN read-only `ModelContext` against the App Group
  /// store — never `PersistenceController.shared`, which would run the ingredient
  /// seeder (a write) in this read-only process. The real query lands in #49;
  /// this proves cross-process store access compiles and resolves.
  ///
  /// `@MainActor` is required (not optional): this project sets
  /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which isolates even `static`
  /// members, so `PersistenceController.schema` / `appGroupStoreURL` are
  /// main-actor-isolated and a nonisolated caller can't reach them — the build
  /// fails without this. #49 does the read via a main-actor hop (spec §5.7).
  @MainActor
  private static func makeContext() throws -> ModelContext {
    let configuration = ModelConfiguration(url: PersistenceController.appGroupStoreURL)
    let container = try ModelContainer(for: PersistenceController.schema, configurations: configuration)
    return ModelContext(container)
  }
}
