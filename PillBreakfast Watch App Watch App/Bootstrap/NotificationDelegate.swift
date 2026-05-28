import os
import SwiftData
import SwiftUI
import UserNotifications

/// Watch app delegate handling notification responses. The default tap (and the
/// "Open app" action) just bring the app forward — it lands on `RightNowView`,
/// which routes into the tap-through queue. Mark-all-taken and Snooze are stubs
/// (EPIC 05 / EPIC 06): they only acknowledge so the system doesn't error.
final class NotificationDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
  private let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Notifications")

  func applicationDidFinishLaunching() {
    UNUserNotificationCenter.current().delegate = self
    NotificationBootstrap.registerCategory()
    // Re-arm reminders from the persisted regimen in case the watch launched
    // without a fresh push (the repeating triggers also survive on their own).
    Task { @MainActor in
      do {
        let snapshot = try RegimenSnapshot.from(context: PersistenceController.shared.container.mainContext)
        await NotificationBootstrap.refresh(from: snapshot)
      } catch {
        logger.error("Launch notification rebuild failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  /// Show dose reminders even when the app is foregrounded.
  func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent _: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }

  func userNotificationCenter(
    _: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    switch response.actionIdentifier {
    case NotificationCategory.Action.markAllTaken:
      // Stub: batch-logging from the notification lands in EPIC 05.
      logger.info("Mark-all-taken action received (stub).")
    case NotificationCategory.Action.snooze:
      // Stub: snooze-until-time flow lands in EPIC 06.
      logger.info("Snooze action received (stub).")
    default:
      // Default tap / Open app: the OS foregrounds us onto RightNowView.
      logger.info("Notification opened the app.")
    }
  }
}
