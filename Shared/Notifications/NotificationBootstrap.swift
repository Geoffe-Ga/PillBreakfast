import os
import UserNotifications

/// Notification setup invoked on the watch: registers the category at launch and,
/// once a non-empty regimen is present, requests authorization and rebuilds the
/// pending dose reminders from scratch.
///
/// Lives in `Shared/` (not the watch target) so the shared
/// `WatchConnectivityCoordinator` can call `refresh(from:)` right after applying a
/// snapshot without a Shared → watch-target dependency. Only the watch invokes it;
/// the iPhone never schedules dose notifications (SPEC §8.1).
@MainActor
public enum NotificationBootstrap {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Notifications")

  /// Called at watch app launch.
  public static func registerCategory() {
    NotificationCategory.register()
  }

  /// Called after the watch applies an incoming regimen snapshot. Authorization is
  /// requested only once there's actually something to remind the user about.
  public static func refresh(from snapshot: RegimenSnapshot) async {
    let center = UNUserNotificationCenter.current()
    if !snapshot.medications.isEmpty {
      await requestAuthorizationIfNeeded(center)
    }
    await NotificationScheduler.rebuildAll(from: snapshot, center: center)
  }

  private static func requestAuthorizationIfNeeded(_ center: UNUserNotificationCenter) async {
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .notDetermined else { return }
    do {
      _ = try await center.requestAuthorization(options: [.alert, .sound])
    } catch {
      logger.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
