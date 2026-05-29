@testable import PillBreakfast_Watch_App_Watch_App
import Testing

@MainActor
struct NotificationActionRouterTests {
  @Test func snoozeActionRoutesToSnooze() {
    let router = NotificationActionRouter.shared
    router.isShowingSnooze = false
    router.handle(actionIdentifier: NotificationCategory.Action.snooze)
    #expect(router.isShowingSnooze)
    router.isShowingSnooze = false // reset shared state
  }

  @Test func unknownActionDoesNotRoute() {
    let router = NotificationActionRouter.shared
    router.isShowingSnooze = false
    router.handle(actionIdentifier: "SOME_OTHER_ACTION")
    #expect(!router.isShowingSnooze)
  }
}
