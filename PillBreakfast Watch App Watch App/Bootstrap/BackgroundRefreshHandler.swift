import os
import WatchKit
import WidgetKit

/// Schedules and handles periodic watchOS background refreshes so the
/// complication updates even when the app is closed — a ~15-minute cadence that
/// keeps the pending count from going stale between foreground sessions.
///
/// `register()` schedules the first refresh (from the app delegate's launch);
/// `handle(_:)` (routed from `WKApplicationDelegate.handle(_ backgroundTasks:)`)
/// reloads now, reschedules, and completes the task.
@MainActor
final class BackgroundRefreshHandler {
  static let shared = BackgroundRefreshHandler()

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "BackgroundRefresh")
  private static let interval: TimeInterval = 15 * 60

  /// Schedules the first background refresh. Safe to call repeatedly — watchOS
  /// coalesces overlapping requests.
  func register() {
    scheduleNextRefresh()
  }

  /// Routes background tasks: an app-refresh task reloads the widget timelines,
  /// reschedules the next refresh, and completes; anything else is acknowledged
  /// so the system doesn't error.
  func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
      if let refresh = task as? WKApplicationRefreshBackgroundTask {
        Task { await WidgetReloadCoordinator.shared.reloadNow() }
        scheduleNextRefresh()
        refresh.setTaskCompletedWithSnapshot(false)
      } else {
        task.setTaskCompletedWithSnapshot(false)
      }
    }
  }

  func scheduleNextRefresh() {
    let fireDate = Date(timeIntervalSinceNow: Self.interval)
    WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: fireDate, userInfo: nil) { error in
      if let error {
        BackgroundRefreshHandler.logger.error(
          "scheduleBackgroundRefresh failed: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }
}
