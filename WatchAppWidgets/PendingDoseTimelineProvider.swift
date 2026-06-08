import Foundation
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
}
