import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import Testing

@MainActor
struct NotificationActionRouterTests {
  @Test func presentSnoozeStashesContextForTheRootView() {
    let router = NotificationActionRouter()
    #expect(router.pendingSnooze == nil)

    let context = SnoozeContext(scheduledDoseID: UUID(), originalScheduledFor: .now, medicationName: "Vitamin D")
    router.presentSnooze(context)
    #expect(router.pendingSnooze == context)
  }
}
