import UserNotifications

/// The notification category and its custom actions (SPEC §8.2). Mark-all-taken
/// is a stub (EPIC 05); Snooze opens the watch `SnoozeView` (EPIC 06 — the
/// reschedule logic itself lands in EPIC_06_ISSUE_02).
public enum NotificationCategory {
  public static let maintenanceDose = "MAINTENANCE_DOSE"

  public enum Action {
    public static let openApp = "OPEN_APP"
    public static let markAllTaken = "MARK_ALL_TAKEN"
    /// `.foreground` so tapping it opens the app onto `SnoozeView` (SPEC §8.3).
    public static let snooze = "com.creekmasons.pillbreakfast.action.snoozeUntilTime"
  }

  /// Builds the maintenance-dose category. Pure (no system access) so its action
  /// set is unit-testable without a notification center.
  public static func makeCategory() -> UNNotificationCategory {
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
      title: "Snooze until…",
      options: [.foreground]
    )
    return UNNotificationCategory(
      identifier: maintenanceDose,
      actions: [openApp, markAllTaken, snooze],
      intentIdentifiers: [],
      options: []
    )
  }

  public static func register(on center: UNUserNotificationCenter = .current()) async {
    // Additive: merge with any existing categories so a future EPIC registering
    // its own category (and vice-versa) doesn't clobber this one.
    let existing = await center.notificationCategories()
    center.setNotificationCategories(existing.union([makeCategory()]))
  }
}
