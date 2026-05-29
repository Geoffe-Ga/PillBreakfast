import UserNotifications

/// The slice of `UNUserNotificationCenter` the snooze logic needs, abstracted so
/// tests can substitute a fake instead of touching the system notification center.
public protocol NotificationScheduling {
  func add(_ request: UNNotificationRequest) async throws
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])
  func pendingNotificationRequests() async -> [UNNotificationRequest]
}

/// UNUserNotificationCenter already provides all three with matching signatures.
extension UNUserNotificationCenter: NotificationScheduling {}
