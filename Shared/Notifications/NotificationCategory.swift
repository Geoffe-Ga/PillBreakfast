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

  public static func register(on center: UNUserNotificationCenter = .current()) async {
    let openApp = UNNotificationAction(
      identifier: Action.openApp,
      title: "Open app",
      options: [.foreground]
    )
    // Stub (EPIC 05). When wired, this background action must deliver its own
    // feedback (haptic / complication refresh) since it has no .foreground.
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
    // Additive: merge with any existing categories so a future EPIC registering
    // its own category (and vice-versa) doesn't clobber this one.
    let existing = await center.notificationCategories()
    center.setNotificationCategories(existing.union([category]))
  }
}
