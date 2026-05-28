import UserNotifications

/// The notification category and its custom actions (SPEC §8.2). Mark-all-taken
/// and Snooze are stubs here — wired in EPIC 05 and EPIC 06 respectively.
public enum NotificationCategory {
  public static let maintenanceDose = "MAINTENANCE_DOSE"

  public enum Action {
    public static let openApp = "OPEN_APP"
    public static let markAllTaken = "MARK_ALL_TAKEN"
    public static let snooze = "SNOOZE_UNTIL_TIME"
  }

  public static func register(on center: UNUserNotificationCenter = .current()) {
    let openApp = UNNotificationAction(
      identifier: Action.openApp,
      title: "Open app",
      options: [.foreground]
    )
    let markAllTaken = UNNotificationAction(
      identifier: Action.markAllTaken,
      title: "Mark all taken",
      options: []
    )
    let snooze = UNNotificationAction(
      identifier: Action.snooze,
      title: "Snooze…",
      options: [.foreground]
    )
    let category = UNNotificationCategory(
      identifier: maintenanceDose,
      actions: [openApp, markAllTaken, snooze],
      intentIdentifiers: [],
      options: []
    )
    center.setNotificationCategories([category])
  }
}
