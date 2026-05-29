@testable import PillBreakfast
import Testing
import UserNotifications

@MainActor
struct NotificationCategoryTests {
  @Test func maintenanceCategoryIncludesSnoozeForegroundAction() throws {
    let category = NotificationCategory.makeCategory()
    #expect(category.identifier == NotificationCategory.maintenanceDose)

    let snooze = try #require(category.actions.first { $0.identifier == NotificationCategory.Action.snooze })
    // Foreground so tapping it opens the app onto SnoozeView (SPEC §8.3).
    #expect(snooze.options.contains(.foreground))
  }
}
