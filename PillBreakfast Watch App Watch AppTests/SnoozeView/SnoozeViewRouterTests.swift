@testable import PillBreakfast_Watch_App_Watch_App
import Testing

@MainActor
struct SnoozeViewRouterTests {
  @Test func routesToPickerBelowThreshold() {
    #expect(SnoozeViewRouter.routeForCount(0) == .picker)
    #expect(SnoozeViewRouter.routeForCount(2) == .picker)
  }

  @Test func routesToWarningAtAndAboveThreshold() {
    // Warn on the fourth snooze — i.e. once already snoozed three times.
    #expect(SnoozeViewRouter.routeForCount(3) == .warning)
    #expect(SnoozeViewRouter.routeForCount(4) == .warning)
  }
}
